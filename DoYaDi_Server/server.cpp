#include <iostream>
#include <thread>
#include <mutex>
#include <string>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <ws2bth.h>     
#include <bthsdpdef.h>  
#include <initguid.h>   
#include <Windows.h>
#include <ViGEm/Client.h>
#include <vector>
#include <algorithm>
#include <chrono>
#include <limits> // DÜZELTME 1: numeric_limits için gerekli kütüphane
#include "plugin_manager.h"

#pragma comment(lib, "ws2_32.lib")      
#pragma comment(lib, "setupapi.lib")    
#pragma comment(lib, "ViGEmClient.lib") 

// Bluetooth Seri Port (SPP) UUID: 00001101-0000-1000-8000-00805F9B34FB
DEFINE_GUID(DoYaDi_SPP_UUID, 0x00001101, 0x0000, 0x1000, 0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb);

#define UDP_DATA_PORT 8888      
#define UDP_DISCOVERY_PORT 8889 
#define MAX_PACKET_SIZE 20
#define BT_BUFFER_SIZE 512

bool isRunning = true;
std::mutex serverMutex;
PVIGEM_CLIENT client = nullptr;
std::string appLang = "tr";
int maxClients = 1;
PluginManager pluginManager;

// Her bağlantı (slot) için bireysel hafıza ve güvenlik yapısı
struct ControllerSlot {
    PVIGEM_TARGET pad = nullptr;
    std::string endpointId = ""; // IP veya BT MAC adresi
    bool isActive = false;
    bool isConnectedToVigem = false;
    bool inputActive = false; // Güvenlik freni için
    std::chrono::steady_clock::time_point lastActiveTime;

    // Klavyede ve Farede çakışmaları önlemek için bireysel hafıza
    int lastMouseClick = 0;
    std::vector<int> lastKeys;
};

std::vector<ControllerSlot> slots;

// Bağlantıyı bulur veya yeni boş bir slot atar
int GetOrAllocateSlot(const std::string& endpointId) {
    std::lock_guard<std::mutex> lock(serverMutex);

    // 1. Zaten kayıtlı bir cihaz mı?
    for (int i = 0; i < maxClients; i++) {
        if (slots[i].isActive && slots[i].endpointId == endpointId) {
            slots[i].lastActiveTime = std::chrono::steady_clock::now();
            slots[i].inputActive = true;
            return i;
        }
    }

    // 2. Yeni cihaz ise boş bir slot bul
    for (int i = 0; i < maxClients; i++) {
        if (!slots[i].isActive) {
            slots[i].isActive = true;
            slots[i].endpointId = endpointId;
            slots[i].lastActiveTime = std::chrono::steady_clock::now();
            slots[i].inputActive = true;

            slots[i].lastMouseClick = 0;
            slots[i].lastKeys.clear();

            // ViGEm'e sadece ilk kullanımda bağla (optimizasyon)
            if (!slots[i].isConnectedToVigem) {
                vigem_target_add(client, slots[i].pad);
                slots[i].isConnectedToVigem = true;
            }

            if (appLang == "english" || appLang == "en") {
                std::cout << "[SYSTEM] Player " << (i + 1) << " connected! (" << endpointId << ")" << std::endl;
            }
            else {
                std::cout << "[SISTEM] Oyuncu " << (i + 1) << " baglandi! (" << endpointId << ")" << std::endl;
            }
            return i;
        }
    }
    return -1; // Slotlar dolu
}

// Güvenlik Freni: İletişim koptuğunda kontrolcüyü merkeze çeker
void ResetSlotInputs(int slotIndex) {
    XUSB_REPORT report;
    XUSB_REPORT_INIT(&report);
    vigem_target_x360_update(client, slots[slotIndex].pad, report);

    // Basılı kalan tuşları ve tıklamaları bırak
    for (int oldKey : slots[slotIndex].lastKeys) {
        INPUT keyUpInput = { 0 };
        keyUpInput.type = INPUT_KEYBOARD;
        keyUpInput.ki.wVk = oldKey;
        keyUpInput.ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(1, &keyUpInput, sizeof(INPUT));
    }
    slots[slotIndex].lastKeys.clear();
    slots[slotIndex].lastMouseClick = 0;
    slots[slotIndex].inputActive = false;
}

// 0. THREAD: Watchdog (Zaman Aşımı ve Slot Temizleyici)
void WatchdogThread() {
    while (isRunning) {
        Sleep(100); // Saniyede 10 kez kontrol et (CPU'yu yormaz)

        std::lock_guard<std::mutex> lock(serverMutex);
        auto now = std::chrono::steady_clock::now();

        for (int i = 0; i < maxClients; i++) {
            if (slots[i].isActive) {
                auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - slots[i].lastActiveTime).count();

                // 500ms bağlantı yoksa (Kablo koptu, ağ düştü) -> Arabayı durdur
                if (ms > 500 && slots[i].inputActive) {
                    ResetSlotInputs(i);
                    slots[i].inputActive = false;
                    if (appLang == "english" || appLang == "en") {
                        std::cerr << "[WATCHDOG] Player " << (i + 1) << " timeout. Safety brake applied." << std::endl;
                    }
                    else {
                        std::cerr << "[WATCHDOG] Oyuncu " << (i + 1) << " yanit vermiyor. Guvenlik freni devrede." << std::endl;
                    }
                }

                // 10 saniye boyunca hiç geri dönmediyse -> Slotu boşa çıkar
                if (ms > 10000) {
                    slots[i].isActive = false;
                    slots[i].endpointId = "";
                    if (appLang == "english" || appLang == "en") {
                        std::cout << "[SYSTEM] Player " << (i + 1) << " slot freed." << std::endl;
                    }
                    else {
                        std::cout << "[SISTEM] Oyuncu " << (i + 1) << " slotu bosa cikarildi." << std::endl;
                    }
                }
            }
        }
    }
}

// Ortak XInput Güncelleme Fonksiyonu
void UpdateGamepad(int slotIndex, unsigned char* buffer, int bytesReceived) {
    std::lock_guard<std::mutex> lock(serverMutex);
    if (slotIndex < 0 || slotIndex >= maxClients || !slots[slotIndex].isActive) return;

    ControllerSlot& slot = slots[slotIndex];
    XUSB_REPORT report;
    XUSB_REPORT_INIT(&report);

    auto MapStick = [](unsigned char val, bool invert) -> SHORT {
        int mapped = (int)((val - 128) * 32767.0 / 127.0);
        if (invert) mapped = -mapped;
        if (mapped > 32767) mapped = 32767;
        if (mapped < -32768) mapped = -32768;
        return (SHORT)mapped;
        };

    // İlk 5 Bayt (Standart Gaz, Fren, Direksiyon ve Tuşlar)
    if (bytesReceived >= 5) {
        int steering = buffer[0];
        int mappedSteer = (int)((steering - 128) * 32767.0 / 127.0);
        if (mappedSteer > 32767) mappedSteer = 32767;
        if (mappedSteer < -32768) mappedSteer = -32768;
        report.sThumbLX = (SHORT)mappedSteer;

        report.bRightTrigger = buffer[1];
        report.bLeftTrigger = buffer[2];

        WORD buttons = (buffer[3] << 8) | buffer[4];
        report.wButtons = buttons;
    }

    // Eğer paket 9 baytsa (Joystick / Debriyaj / El Freni verileri eklenmişse)
    if (bytesReceived >= 9) {

        // Sol Joystick (Eğer ekranda sol joystick eklendiyse, jiroskopu ezer)
        if (buffer[5] != 128 && buffer[5] != 0) {
            report.sThumbLX = MapStick(buffer[5], false);
        }
        if (buffer[6] != 128 && buffer[6] != 0) {
            report.sThumbLY = MapStick(buffer[6], true); // Y ekseni ters (YUKARI pozitif)
        }

        // Sağ Joystick / El Freni / Debriyaj (Eski çalışan sunucu.txt mantığı: Y-ekseni ters)
        if (buffer[7] != 128 || buffer[8] != 128) {
            report.sThumbRX = MapStick(buffer[7], false);
            report.sThumbRY = MapStick(buffer[8], true); // Y ekseni ters (YUKARI pozitif)
        }
    }

    if (bytesReceived >= 16) {

        // --- 1. FARE HAREKETİ (Byte 9-10) ---
        int rawMouseX = buffer[9];
        int rawMouseY = buffer[10];

        if (rawMouseX != 128 || rawMouseY != 128) {
            int deltaX = (rawMouseX - 128) * 2; // Çarpı 2: Hassasiyet
            int deltaY = (rawMouseY - 128) * 2;

            INPUT moveInput = { 0 };
            moveInput.type = INPUT_MOUSE;
            moveInput.mi.dx = deltaX;
            moveInput.mi.dy = deltaY;
            moveInput.mi.dwFlags = MOUSEEVENTF_MOVE;
            SendInput(1, &moveInput, sizeof(INPUT));
        }

        // --- 2. FARE TIKLAMALARI (Byte 11) ---
        int currentMouseClick = buffer[11];
        if (currentMouseClick != slot.lastMouseClick) {
            INPUT clickInput = { 0 };
            clickInput.type = INPUT_MOUSE;

            if (currentMouseClick == 1) clickInput.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
            else if (slot.lastMouseClick == 1) clickInput.mi.dwFlags = MOUSEEVENTF_LEFTUP;

            if (currentMouseClick == 2) clickInput.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
            else if (slot.lastMouseClick == 2) clickInput.mi.dwFlags = MOUSEEVENTF_RIGHTUP;

            if (currentMouseClick == 3) clickInput.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
            else if (slot.lastMouseClick == 3) clickInput.mi.dwFlags = MOUSEEVENTF_MIDDLEUP;

            SendInput(1, &clickInput, sizeof(INPUT));
            slot.lastMouseClick = currentMouseClick;
        }

        // --- 3. KLAVYE ANTI-GHOSTING (Byte 12-15) ---
        std::vector<int> currentKeys;
        for (int i = 12; i <= 15; i++) {
            if (buffer[i] != 0) {
                currentKeys.push_back(buffer[i]);
            }
        }

        // Bırakılan Tuşları Bul
        for (int oldKey : slot.lastKeys) {
            if (std::find(currentKeys.begin(), currentKeys.end(), oldKey) == currentKeys.end()) {
                INPUT keyUpInput = { 0 };
                keyUpInput.type = INPUT_KEYBOARD;
                if (oldKey >= 193 && oldKey <= 219) {
                    WORD symbol = 0;
                    if (oldKey == 193) symbol = '@';
                    else if (oldKey == 194) symbol = '#';
                    else if (oldKey == 195) symbol = '$';
                    else if (oldKey == 196) symbol = '%';
                    else if (oldKey == 197) symbol = '^';
                    else if (oldKey == 198) symbol = '&';
                    else if (oldKey == 199) symbol = '(';
                    else if (oldKey == 200) symbol = ')';
                    else if (oldKey == 201) symbol = '?';
                    else if (oldKey == 202) symbol = '{';
                    else if (oldKey == 203) symbol = '}';
                    else if (oldKey == 204) symbol = '_';
                    else if (oldKey == 205) symbol = 0x00E6; // æ
                    else if (oldKey == 206) symbol = 0x00C6; // Æ
                    else if (oldKey == 207) symbol = '!';
                    else if (oldKey == 208) symbol = '<';
                    else if (oldKey == 209) symbol = '>';
                    else if (oldKey == 210) symbol = ':';
                    else if (oldKey == 211) symbol = '"';
                    else if (oldKey == 212) symbol = '|';
                    else if (oldKey == 213) symbol = 0x0131; // ı
                    else if (oldKey == 214) symbol = 0x011F; // ğ
                    else if (oldKey == 215) symbol = 0x00FC; // ü
                    else if (oldKey == 216) symbol = 0x015F; // ş
                    else if (oldKey == 217) symbol = 0x0130; // İ
                    else if (oldKey == 218) symbol = 0x00F6; // ö
                    else if (oldKey == 219) symbol = 0x00E7; // ç
                    
                    keyUpInput.ki.wScan = symbol;
                    keyUpInput.ki.wVk = 0;
                    keyUpInput.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
                } else {
                    keyUpInput.ki.wVk = oldKey;
                    keyUpInput.ki.dwFlags = KEYEVENTF_KEYUP;
                }
                SendInput(1, &keyUpInput, sizeof(INPUT));
            }
        }

        // Yeni Basılan Tuşları Bul
        for (int newKey : currentKeys) {
            if (std::find(slot.lastKeys.begin(), slot.lastKeys.end(), newKey) == slot.lastKeys.end()) {
                INPUT keyDownInput = { 0 };
                keyDownInput.type = INPUT_KEYBOARD;
                if (newKey >= 193 && newKey <= 219) {
                    WORD symbol = 0;
                    if (newKey == 193) symbol = '@';
                    else if (newKey == 194) symbol = '#';
                    else if (newKey == 195) symbol = '$';
                    else if (newKey == 196) symbol = '%';
                    else if (newKey == 197) symbol = '^';
                    else if (newKey == 198) symbol = '&';
                    else if (newKey == 199) symbol = '(';
                    else if (newKey == 200) symbol = ')';
                    else if (newKey == 201) symbol = '?';
                    else if (newKey == 202) symbol = '{';
                    else if (newKey == 203) symbol = '}';
                    else if (newKey == 204) symbol = '_';
                    else if (newKey == 205) symbol = 0x00E6; // æ
                    else if (newKey == 206) symbol = 0x00C6; // Æ
                    else if (newKey == 207) symbol = '!';
                    else if (newKey == 208) symbol = '<';
                    else if (newKey == 209) symbol = '>';
                    else if (newKey == 210) symbol = ':';
                    else if (newKey == 211) symbol = '"';
                    else if (newKey == 212) symbol = '|';
                    else if (newKey == 213) symbol = 0x0131; // ı
                    else if (newKey == 214) symbol = 0x011F; // ğ
                    else if (newKey == 215) symbol = 0x00FC; // ü
                    else if (newKey == 216) symbol = 0x015F; // ş
                    else if (newKey == 217) symbol = 0x0130; // İ
                    else if (newKey == 218) symbol = 0x00F6; // ö
                    else if (newKey == 219) symbol = 0x00E7; // ç
                    
                    keyDownInput.ki.wScan = symbol;
                    keyDownInput.ki.wVk = 0;
                    keyDownInput.ki.dwFlags = KEYEVENTF_UNICODE;
                } else {
                    keyDownInput.ki.wVk = newKey;
                    keyDownInput.ki.dwFlags = 0; // 0 = Basılı tut
                }
                SendInput(1, &keyDownInput, sizeof(INPUT));
            }
        }

        slot.lastKeys = currentKeys;
    }

    vigem_target_x360_update(client, slot.pad, report);
}

// 1. THREAD: Cihaz Keşfi 
void DiscoveryListener() {
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in serverAddr = { 0 };
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(UDP_DISCOVERY_PORT);
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        if (appLang == "english" || appLang == "en") {
            std::cerr << "\n[ERROR] Port 8889 is busy! Please close old DoYaDi instances." << std::endl;
        }
        else {
            std::cerr << "\n[HATA] 8889 Portu mesgul! Eski DoYaDi'leri kapatin." << std::endl;
        }
        closesocket(sock);
        return;
    }

    char buffer[256];
    sockaddr_in clientAddr;
    int clientAddrLen = sizeof(clientAddr);

    while (isRunning) {
        int bytes = recvfrom(sock, buffer, 255, 0, (sockaddr*)&clientAddr, &clientAddrLen);
        if (bytes > 0) {
            buffer[bytes] = '\0';
            if (std::string(buffer) == "DOYADI_SEARCH") {
                std::string reply = "DOYADI_PC_OK";
                sendto(sock, reply.c_str(), (int)reply.length(), 0, (sockaddr*)&clientAddr, clientAddrLen);
            }
        }
    }
    closesocket(sock);
}

// 2. THREAD: Wi-Fi ve USB Dinleyici 
void UdpDataListener() {
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in serverAddr;
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(UDP_DATA_PORT);
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        if (appLang == "english" || appLang == "en") {
            std::cerr << "\n[ERROR] Port 8888 is busy! Please close old DoYaDi instances." << std::endl;
        }
        else {
            std::cerr << "\n[HATA] 8888 Portu mesgul! Eski DoYaDi'leri kapatin." << std::endl;
        }
        closesocket(sock);
        return;
    }

    // 500ms Socket Zaman Aşımı (Threadi kilitlememek için)
    DWORD timeout = 500;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

    unsigned char buffer[MAX_PACKET_SIZE];
    sockaddr_in clientAddr;
    int clientAddrLen = sizeof(clientAddr);

    if (appLang == "english" || appLang == "en") {
        std::cout << "[WIFI/USB] Searching for DoYaDi app (Port: 8889)..." << std::endl;
    }
    else {
        std::cout << "[WIFI/USB] Agda DoYaDi uygulamasi araniyor (Port: 8889)..." << std::endl;
    }

    while (isRunning) {
        int bytes = recvfrom(sock, (char*)buffer, MAX_PACKET_SIZE, 0, (sockaddr*)&clientAddr, &clientAddrLen);

        if (bytes > 0 && (bytes == 6 || bytes == 10 || bytes == 17)) {
            // GÜMRÜK KONTROLÜ (Sihirli Bayt 221)
            if (buffer[bytes - 1] != 221) {
                continue; // Başka bir programdan gelen çöp veriyse yoksay
            }
            char ipStr[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(clientAddr.sin_addr), ipStr, INET_ADDRSTRLEN);
            std::string endpointId = "UDP_" + std::string(ipStr);

            int slotIndex = GetOrAllocateSlot(endpointId);
            if (slotIndex != -1) {
                UpdateGamepad(slotIndex, buffer, bytes - 1);
            }
        }
    }
    closesocket(sock);
}

// Bluetooth Dinleyici
void BluetoothListener() {
    while (isRunning) {
        SOCKET bthSock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
        if (bthSock == INVALID_SOCKET) {
            Sleep(3000); // Bluetooth kapalıysa uykuya yat, çökmek yok!
            continue;
        }

        ULONG auth = 0;
        setsockopt(bthSock, SOL_RFCOMM, SO_BTH_AUTHENTICATE, (char*)&auth, sizeof(auth));

        SOCKADDR_BTH bthAddr = { 0 };
        bthAddr.addressFamily = AF_BTH;
        bthAddr.port = BT_PORT_ANY;

        if (bind(bthSock, (sockaddr*)&bthAddr, sizeof(bthAddr)) == SOCKET_ERROR) {
            closesocket(bthSock);
            Sleep(3000); // Başka bir sorun varsa bekle ve tekrar dene
            continue;
        }

        int addrLen = sizeof(bthAddr);
        getsockname(bthSock, (sockaddr*)&bthAddr, &addrLen);

        CSADDR_INFO addrInfo = { 0 };
        addrInfo.LocalAddr.lpSockaddr = (sockaddr*)&bthAddr;
        addrInfo.LocalAddr.iSockaddrLength = sizeof(bthAddr);
        addrInfo.iSocketType = SOCK_STREAM;
        addrInfo.iProtocol = BTHPROTO_RFCOMM;

        WSAQUERYSET qs = { 0 };
        qs.dwSize = sizeof(qs);
        qs.lpszServiceInstanceName = (LPWSTR)L"DoYaDi Server";
        qs.lpServiceClassId = (LPGUID)&DoYaDi_SPP_UUID;
        qs.dwNameSpace = NS_BTH;
        qs.dwNumberOfCsAddrs = 1;
        qs.lpcsaBuffer = &addrInfo;

        if (WSASetService(&qs, RNRSERVICE_REGISTER, 0) != SOCKET_ERROR) {
            if (appLang == "english" || appLang == "en") {
                std::cout << "[BLUETOOTH] Ready. Waiting for connection..." << std::endl;
            }
            else {
                std::cout << "[BLUETOOTH] Hazir. Baglanti bekleniyor..." << std::endl;
            }
        }

        listen(bthSock, 1);

        while (isRunning) {
            SOCKADDR_BTH clientAddr;
            int clientAddrLen = sizeof(clientAddr);
            SOCKET clientSock = accept(bthSock, (sockaddr*)&clientAddr, &clientAddrLen);

            if (clientSock != INVALID_SOCKET) {
                std::string endpointId = "BT_" + std::to_string(clientAddr.btAddr);
                int slotIndex = GetOrAllocateSlot(endpointId);

                if (slotIndex == -1) {
                    closesocket(clientSock); // Server dolu, reddet
                    continue;
                }

                unsigned char recvBuf[BT_BUFFER_SIZE];
                std::vector<unsigned char> btStreamBuffer;
                btStreamBuffer.reserve(1024);

                DWORD timeout = 500;
                setsockopt(clientSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

                while (isRunning) {
                    int bytes = recv(clientSock, (char*)recvBuf, BT_BUFFER_SIZE, 0);

                    if (bytes == SOCKET_ERROR) {
                        int err = WSAGetLastError();
                        if (err == WSAETIMEDOUT) {
                            continue;
                        }
                        else {
                            break; // Kopma veya donanım hatası
                        }
                    }
                    else if (bytes == 0) {
                        break; // Telefon bağlantıyı bilerek kapattı
                    }

                    // Gelen baytları stream tamponuna ekle
                    btStreamBuffer.insert(btStreamBuffer.end(), recvBuf, recvBuf + bytes);

                    // Akış Tamponu Ayrıştırıcısı (Stream Parser): Paket sınırlarını koru ve ayır
                    while (!btStreamBuffer.empty()) {
                        // 1. DOYADI_ADDON_LIST string kontrolü (17 bayt)
                        if (btStreamBuffer.size() >= 17) {
                            std::string msg((char*)btStreamBuffer.data(), 17);
                            if (msg == "DOYADI_ADDON_LIST") {
                                auto response = pluginManager.GetAddonListForBluetooth();
                                send(clientSock, (const char*)response.data(), (int)response.size(), 0);
                                btStreamBuffer.erase(btStreamBuffer.begin(), btStreamBuffer.begin() + 17);
                                continue;
                            }
                        }

                        // 2. Sürüş Paketleri Kontrolü (6, 10 veya 17 bayt; son bayt sihirli bayt 221 olmalı)
                        // ÖNCELİK SÜRÜŞ PAKETLERİNDE: steerByte == 238 (0xEE) olsa dahi sihirli bayt 221 kontrolü sayesinde
                        // sürüş paketleri KESİNLİKLE eklenti komutlarıyla karıştırılamaz!
                        bool parsedDrivingPacket = false;

                        if (btStreamBuffer.size() >= 17 && btStreamBuffer[16] == 221) {
                            if (!slots[slotIndex].isActive) {
                                slotIndex = GetOrAllocateSlot(endpointId);
                                if (slotIndex == -1) break;
                            }
                            slots[slotIndex].lastActiveTime = std::chrono::steady_clock::now();
                            slots[slotIndex].inputActive = true;
                            UpdateGamepad(slotIndex, btStreamBuffer.data(), 16);
                            btStreamBuffer.erase(btStreamBuffer.begin(), btStreamBuffer.begin() + 17);
                            parsedDrivingPacket = true;
                        }
                        else if (btStreamBuffer.size() >= 10 && btStreamBuffer[9] == 221) {
                            if (!slots[slotIndex].isActive) {
                                slotIndex = GetOrAllocateSlot(endpointId);
                                if (slotIndex == -1) break;
                            }
                            slots[slotIndex].lastActiveTime = std::chrono::steady_clock::now();
                            slots[slotIndex].inputActive = true;
                            UpdateGamepad(slotIndex, btStreamBuffer.data(), 9);
                            btStreamBuffer.erase(btStreamBuffer.begin(), btStreamBuffer.begin() + 10);
                            parsedDrivingPacket = true;
                        }
                        else if (btStreamBuffer.size() >= 6 && btStreamBuffer[5] == 221) {
                            if (!slots[slotIndex].isActive) {
                                slotIndex = GetOrAllocateSlot(endpointId);
                                if (slotIndex == -1) break;
                            }
                            slots[slotIndex].lastActiveTime = std::chrono::steady_clock::now();
                            slots[slotIndex].inputActive = true;
                            UpdateGamepad(slotIndex, btStreamBuffer.data(), 5);
                            btStreamBuffer.erase(btStreamBuffer.begin(), btStreamBuffer.begin() + 6);
                            parsedDrivingPacket = true;
                        }

                        if (parsedDrivingPacket) continue;

                        // 3. Ek Paket (DLC) Komutu (3 Bayt: [0xEE, PluginID, Status])
                        if (btStreamBuffer.size() >= 3 && btStreamBuffer[0] == 0xEE) {
                            unsigned char pluginID = btStreamBuffer[1];
                            bool turnOn = (btStreamBuffer[2] == 0x01);
                            // Ana BT recv döngüsünü bloklamayacak şekilde ayrı thread'de çalıştır
                            // Böylece DLL'in StartPlugin fonksiyonu uzun sürse bile
                            // sürüş verisi akmaya devam eder.
                            std::thread([pluginID, turnOn]() {
                                try {
                                    pluginManager.ProcessCommand(pluginID, turnOn, "BT");
                                } catch (...) {
                                    std::cerr << "[HATA] BT ProcessCommand exception!" << std::endl;
                                }
                            }).detach();
                            btStreamBuffer.erase(btStreamBuffer.begin(), btStreamBuffer.begin() + 3);
                            continue;
                        }

                        // Yeterli bayt birikmemişse döngüden çıkıp yeni recv bekle
                        if (btStreamBuffer.size() < 17) {
                            break;
                        } else {
                            // Tanınmayan bayt ise 1 bayt kaydırarak re-sync yap
                            btStreamBuffer.erase(btStreamBuffer.begin());
                        }
                    }
                }
                closesocket(clientSock);
            }
        }
        WSASetService(&qs, RNRSERVICE_DEREGISTER, 0);
        closesocket(bthSock);
    }
}

int main() {
    char langBuffer[10];
    GetPrivateProfileStringA("Settings", "Language", "tr", langBuffer, 10, ".\\config.ini");
    appLang = std::string(langBuffer);

    if (appLang == "english" || appLang == "en") {
        std::cout << "========================================" << std::endl;
        std::cout << "          DoYaDi - PC SERVER            " << std::endl;
        std::cout << "========================================\n" << std::endl;
        std::cout << "Enter max number of devices (1-4): ";
    }
    else {
        std::cout << "========================================" << std::endl;
        std::cout << "         DoYaDi - PC SUNUCUSU           " << std::endl;
        std::cout << "========================================\n" << std::endl;
        std::cout << "Baglanacak maksimum cihaz sayisini girin (1-4): ";
    }

    std::cin >> maxClients;
    if (maxClients < 1) maxClients = 1;
    if (maxClients > 4) maxClients = 4;

    // Klavyede girilen \n (Enter) karakterini temizle ki sonda hemen kapanmasın
    std::cin.ignore((std::numeric_limits<std::streamsize>::max)(), '\n');

    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    client = vigem_alloc();
    const auto retval = vigem_connect(client);

    if (!VIGEM_SUCCESS(retval)) {
        if (appLang == "english" || appLang == "en") {
            std::cerr << "[ERROR] ViGEmBus Driver not found!" << std::endl;
        }
        else {
            std::cerr << "[HATA] ViGEmBus Surucusu bulunamadi!" << std::endl;
        }
        system("pause");
        return -1;
    }

    // Seçilen sayı kadar boş slot oluştur ve ViGEm'e HEMEN bağla ki Windows ve Oyunlar açılışta kontrolcüyü hazır görsün!
    for (int i = 0; i < maxClients; i++) {
        ControllerSlot s;
        s.pad = vigem_target_x360_alloc();
        vigem_target_add(client, s.pad);
        s.isConnectedToVigem = true;
        slots.push_back(s);
    }

    pluginManager.Init(".\\DoYaDi_Ek");

    std::thread watchdog(WatchdogThread);
    std::thread udpDiscovery(DiscoveryListener);
    std::thread udpData(UdpDataListener);
    std::thread btData(BluetoothListener);

    if (appLang == "english" || appLang == "en") {
        std::cout << ">>> Server is running. Press ENTER to stop... <<<" << std::endl;
    }
    else {
        std::cout << ">>> Sunucu calisiyor. Kapatmak icin ENTER'a basin... <<<" << std::endl;
    }

    std::cin.get();
    isRunning = false;

    pluginManager.Shutdown();

    for (int i = 0; i < maxClients; i++) {
        if (slots[i].isConnectedToVigem) {
            vigem_target_remove(client, slots[i].pad);
        }
        vigem_target_free(slots[i].pad);
    }

    vigem_disconnect(client);
    vigem_free(client);
    WSACleanup();

    watchdog.detach();
    udpDiscovery.detach();
    udpData.detach();
    btData.detach();

    return 0;
}