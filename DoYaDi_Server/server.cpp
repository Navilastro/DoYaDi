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

#pragma comment(lib, "ws2_32.lib")      
#pragma comment(lib, "setupapi.lib")    
#pragma comment(lib, "ViGEmClient.lib") 

// Bluetooth Seri Port (SPP) UUID: 00001101-0000-1000-8000-00805F9B34FB
DEFINE_GUID(DoYaDi_SPP_UUID, 0x00001101, 0x0000, 0x1000, 0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb);

#define UDP_DATA_PORT 8888      
#define UDP_DISCOVERY_PORT 8889 
#define MAX_PACKET_SIZE 16

bool isRunning = true;
std::mutex serverMutex;
PVIGEM_CLIENT client = nullptr;
std::string appLang = "tr";
int maxClients = 1;

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
            slots[i].inputActive = false;
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

    // İlk 5 Bayt (Standart Gaz, Fren, Direksiyon ve Tuşlar)
    if (bytesReceived >= 5) {
        int steering = buffer[0];
        report.sThumbLX = (SHORT)((steering - 128) * 256);

        report.bRightTrigger = buffer[1];
        report.bLeftTrigger = buffer[2];

        WORD buttons = (buffer[3] << 8) | buffer[4];
        report.wButtons = buttons;
    }

    // Eğer paket 9 baytsa (Joystick verileri eklenmişse)
    if (bytesReceived >= 9) {
        // Sol Joystick jiroskopu ezmek için kullanılıyorsa
        if (buffer[5] != 128 || buffer[6] != 128) {
            report.sThumbLX = (SHORT)((buffer[5] - 128) * 256);
            report.sThumbLY = (SHORT)((buffer[6] - 128) * -256); // Y ekseni ters
        }

        report.sThumbRX = (SHORT)((buffer[7] - 128) * 256);
        report.sThumbRY = (SHORT)((buffer[8] - 128) * -256); // Y ekseni ters
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
                keyUpInput.ki.wVk = oldKey;
                keyUpInput.ki.dwFlags = KEYEVENTF_KEYUP;
                SendInput(1, &keyUpInput, sizeof(INPUT));
            }
        }

        // Yeni Basılan Tuşları Bul
        for (int newKey : currentKeys) {
            if (std::find(slot.lastKeys.begin(), slot.lastKeys.end(), newKey) == slot.lastKeys.end()) {
                INPUT keyDownInput = { 0 };
                keyDownInput.type = INPUT_KEYBOARD;
                keyDownInput.ki.wVk = newKey;
                keyDownInput.ki.dwFlags = 0; // 0 = Basılı tut
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

        if (bytes > 0 && (bytes == 5 || bytes == 9 || bytes == 16)) {
            char ipStr[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(clientAddr.sin_addr), ipStr, INET_ADDRSTRLEN);
            std::string endpointId = "UDP_" + std::string(ipStr);

            int slotIndex = GetOrAllocateSlot(endpointId);
            if (slotIndex != -1) {
                UpdateGamepad(slotIndex, buffer, bytes);
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

                unsigned char buffer[MAX_PACKET_SIZE];
                DWORD timeout = 500;
                setsockopt(clientSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

                while (isRunning) {
                    int bytes = recv(clientSock, (char*)buffer, MAX_PACKET_SIZE, 0);

                    if (bytes == SOCKET_ERROR) {
                        int err = WSAGetLastError();
                        if (err == WSAETIMEDOUT) {
                            // Sadece 500ms sessizlik oldu, kopma yok. Dinlemeye devam et.
                            // (Güvenlik frenini zaten Watchdog arka planda yapıyor)
                            continue;
                        }
                        else {
                            break; // Gerçek bir kopma veya donanım hatası
                        }
                    }
                    else if (bytes == 0) {
                        break; // Telefon bağlantıyı bilerek kapattı
                    }
                    else if (bytes == 5 || bytes == 9 || bytes == 16) {
                        if (!slots[slotIndex].isActive) {
                            slotIndex = GetOrAllocateSlot(endpointId);
                            if (slotIndex == -1) break; // Sunucu aniden dolduysa döngüden çık
                        }
                        slots[slotIndex].lastActiveTime = std::chrono::steady_clock::now();
                        slots[slotIndex].inputActive = true;
                        UpdateGamepad(slotIndex, buffer, bytes);
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

    // Seçilen sayı kadar boş slot oluştur
    for (int i = 0; i < maxClients; i++) {
        ControllerSlot s;
        s.pad = vigem_target_x360_alloc();
        slots.push_back(s);
    }

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