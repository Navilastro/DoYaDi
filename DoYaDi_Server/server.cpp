#include <iostream>
#include <thread>
#include <mutex>
#include <atomic>      // FAZ 0: Data race önleme
#include <stop_token>  // FAZ 0: jthread güvenli kapanış
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

std::atomic<bool> isRunning{true}; // FAZ 0: Data race güvenliği
std::mutex serverMutex;
PVIGEM_CLIENT client = nullptr;
std::string appLang = "tr";
int maxClients = 8; // Dinamik Tak & Çalıştır: 1-8 Oyuncu Desteği
PluginManager pluginManager;

// FAZ 0: Fire-and-forget thread sızıntısını önlemek için
// BT ProcessCommand thread'lerini takip eden vektör
std::vector<std::jthread> pendingTasks;
std::mutex pendingTasksMutex;

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
            if (!slots[i].inputActive) {
                if (appLang == "english" || appLang == "en") {
                    std::cout << "[SYSTEM] Player " << (i + 1) << " reconnected! (" << endpointId << ")" << std::endl;
                }
                else {
                    std::cout << "[SISTEM] Oyuncu " << (i + 1) << " yeniden baglandi! (" << endpointId << ")" << std::endl;
                }
            }
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

#ifndef SIO_UDP_CONNRESET
#define SIO_UDP_CONNRESET _WSAIOW(IOC_VENDOR, 12)
#endif

// ─────────────────────────────────────────────────────────────────────────────
// Unicode Klavye Karakter Haritalaması
// ─────────────────────────────────────────────────────────────────────────────
// Windows'ta bazı tuşlar (/, [, ], ;, \, ', -, =, ,, .) ve Türkçe harfler
// (ğ, ü, ş, İ, ö, ç, ı) sanal tuş (VK_OEM_...) koduyla gönderildiğinde, hedef PC'nin
// aktif klavye düzenine (TR-Q, US, vb.) göre farklı harflere dönüşür (Örn: '/' tuşu
// VK_OEM_2 olarak gönderildiğinde Türkçe klavyede 'ü' harfine dönüşür).
// KEYEVENTF_UNICODE kullanılarak karakter doğrudan hedef dilden bağımsız olarak iletilir.
WORD GetUnicodeSymbol(int key) {
    // Özel Shift ve Noktalama Karakterleri (193-218)
    if (key == 193) return '@';
    if (key == 194) return '#';
    if (key == 195) return '$';
    if (key == 196) return '%';
    if (key == 197) return '^';
    if (key == 198) return '&';
    if (key == 199) return '(';
    if (key == 200) return ')';
    if (key == 201) return '?';
    if (key == 202) return '{';
    if (key == 203) return '}';
    if (key == 204) return '_';
    if (key == 205) return 0x00E6; // æ
    if (key == 206) return 0x00C6; // Æ
    if (key == 207) return '!';
    if (key == 208) return '<';
    if (key == 209) return '>';
    if (key == 210) return ':';
    if (key == 211) return '"';
    if (key == 212) return '|';
    if (key == 213) return 0x0131; // ı
    if (key == 214) return 0x011F; // ğ
    if (key == 215) return 0x00FC; // ü
    if (key == 216) return 0x015F; // ş
    if (key == 217) return 0x0130; // İ
    if (key == 218) return 0x00F6; // ö

    // Temel Semboller (136-147)
    if (key == 136) return 0x00E7; // ç
    if (key == 137) return '+';
    if (key == 138) return '\'';
    if (key == 139) return '-';
    if (key == 140) return '/';
    if (key == 141) return '[';
    if (key == 142) return ']';
    if (key == 143) return ';';
    if (key == 144) return '\\';
    if (key == 145) return ',';
    if (key == 146) return '.';
    if (key == 147) return '=';

    // Geriye Dönük Uyumluluk (Eski OEM Kodları):
    // Kullanıcının kayıtlı ayarlarında eski VK kodları kaldıysa bile
    // sunucu bunları otomatik olarak doğru Unicode karakterine dönüştürür.
    if (key == 191) return '/';   // Eski OEM_2 (Türkçe klavyede 'ü' çıkmasını önler!)
    if (key == 219) return '[';   // Eski OEM_4 (Türkçe klavyede 'ğ' çıkmasını önler!)
    if (key == 221) return ']';   // Eski OEM_6
    if (key == 186) return ';';   // Eski OEM_1 (Türkçe klavyede 'ş' çıkmasını önler!)
    if (key == 220) return '\\';  // Eski OEM_5 (Türkçe klavyede 'ç' çıkmasını önler!)
    if (key == 222) return '\'';  // Eski OEM_7 (Türkçe klavyede 'i' çıkmasını önler!)
    if (key == 189) return '-';   // Eski OEM_MINUS
    if (key == 187) return '=';   // Eski OEM_PLUS
    if (key == 188) return ',';   // Eski OEM_COMMA
    if (key == 190) return '.';   // Eski OEM_PERIOD

    return 0; // Standart Sanal Tuş (VK)
}

void SendKeyInput(int key, bool isDown) {
    INPUT input = { 0 };
    input.type = INPUT_KEYBOARD;
    WORD symbol = GetUnicodeSymbol(key);
    if (symbol != 0) {
        input.ki.wScan = symbol;
        input.ki.wVk = 0;
        input.ki.dwFlags = KEYEVENTF_UNICODE | (isDown ? 0 : KEYEVENTF_KEYUP);
    } else {
        input.ki.wVk = (WORD)key;
        input.ki.wScan = (WORD)MapVirtualKeyA(key, MAPVK_VK_TO_VSC);
        input.ki.dwFlags = isDown ? 0 : KEYEVENTF_KEYUP;
        if (key == VK_LEFT || key == VK_RIGHT || key == VK_UP || key == VK_DOWN ||
            key == VK_HOME || key == VK_END || key == VK_PRIOR || key == VK_NEXT ||
            key == VK_INSERT || key == VK_DELETE) {
            input.ki.dwFlags |= KEYEVENTF_EXTENDEDKEY;
        }
    }
    SendInput(1, &input, sizeof(INPUT));
}

// Güvenlik Freni: İletişim koptuğunda kontrolcüyü merkeze çeker
void ResetSlotInputs(int slotIndex) {
    if (slots[slotIndex].isConnectedToVigem && slots[slotIndex].pad != nullptr) {
        XUSB_REPORT report;
        XUSB_REPORT_INIT(&report);
        vigem_target_x360_update(client, slots[slotIndex].pad, report);
    }

    // Basılı kalan tuşları bırak
    for (int oldKey : slots[slotIndex].lastKeys) {
        SendKeyInput(oldKey, false);
    }
    slots[slotIndex].lastKeys.clear();

    // Basılı kalan fare tıklamalarını bırak
    int lastClick = slots[slotIndex].lastMouseClick;
    if (lastClick >= 1 && lastClick <= 3) {
        INPUT clickUpInput = { 0 };
        clickUpInput.type = INPUT_MOUSE;
        if (lastClick == 1) clickUpInput.mi.dwFlags = MOUSEEVENTF_LEFTUP;
        else if (lastClick == 2) clickUpInput.mi.dwFlags = MOUSEEVENTF_RIGHTUP;
        else if (lastClick == 3) clickUpInput.mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
        SendInput(1, &clickUpInput, sizeof(INPUT));
    }
    slots[slotIndex].lastMouseClick = 0;
    slots[slotIndex].inputActive = false;
}

// 0. THREAD: Watchdog (Zaman Aşımı ve Slot Temizleyici)
// FAZ 0: std::stop_token ile güvenli kapanış desteği
void WatchdogThread(std::stop_token stoken) {
    while (!stoken.stop_requested()) {
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

                // 10 saniye boyunca hiç geri dönmediyse -> Kolu Windows'tan çıkar ve slotu boşa çıkar
                if (ms > 10000) {
                    slots[i].isActive = false;
                    slots[i].endpointId = "";
                    if (slots[i].isConnectedToVigem) {
                        vigem_target_remove(client, slots[i].pad);
                        slots[i].isConnectedToVigem = false;
                    }
                    if (appLang == "english" || appLang == "en") {
                        std::cout << "[SYSTEM] Player " << (i + 1) << " disconnected. Virtual controller unplugged." << std::endl;
                    }
                    else {
                        std::cout << "[SISTEM] Oyuncu " << (i + 1) << " ayrildi. Sanal kontrolcu cikarildi." << std::endl;
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

        // --- 2. FARE TIKLAMALARI VE JESTLER (Byte 11) ---
        int currentMouseClick = buffer[11];

        // SÜREKLİ KAYDIRMA (Scroll) - Sadece değiştiğinde değil, her UDP paketinde çalışır
        if (currentMouseClick == 4 || currentMouseClick == 5) {
            INPUT scrollInput = { 0 };
            scrollInput.type = INPUT_MOUSE;
            scrollInput.mi.dwFlags = MOUSEEVENTF_WHEEL;
            
            // WHEEL_DELTA(120) çok hızlı olduğu için pürüzsüz kaydırma için 30'a düşürüldü
            if (currentMouseClick == 4) scrollInput.mi.mouseData = 30;
            else if (currentMouseClick == 5) scrollInput.mi.mouseData = static_cast<DWORD>(-30);
            
            SendInput(1, &scrollInput, sizeof(INPUT));
        }

        if (currentMouseClick != slot.lastMouseClick) {
            INPUT clickInput = { 0 };
            clickInput.type = INPUT_MOUSE;

            if (currentMouseClick == 1) clickInput.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
            else if (slot.lastMouseClick == 1) clickInput.mi.dwFlags = MOUSEEVENTF_LEFTUP;

            if (currentMouseClick == 2) clickInput.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
            else if (slot.lastMouseClick == 2) clickInput.mi.dwFlags = MOUSEEVENTF_RIGHTUP;

            if (currentMouseClick == 3) clickInput.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
            else if (slot.lastMouseClick == 3) clickInput.mi.dwFlags = MOUSEEVENTF_MIDDLEUP;

            if (clickInput.mi.dwFlags != 0) {
                SendInput(1, &clickInput, sizeof(INPUT));
            }

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
                SendKeyInput(oldKey, false);
            }
        }

        // Yeni Basılan Tuşları Bul
        for (int newKey : currentKeys) {
            if (std::find(slot.lastKeys.begin(), slot.lastKeys.end(), newKey) == slot.lastKeys.end()) {
                SendKeyInput(newKey, true);
            }
        }

        slot.lastKeys = currentKeys;
    }

    if (slot.isConnectedToVigem && slot.pad != nullptr) {
        vigem_target_x360_update(client, slot.pad, report);
    }
}

// 1. THREAD: Cihaz Keşfi 
// FAZ 0: WSAPoll non-blocking + stop_token ile güvenli kapanış
void DiscoveryListener(std::stop_token stoken) {
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in serverAddr = { 0 };
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(UDP_DISCOVERY_PORT);
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        if (appLang == "english" || appLang == "en") {
            std::cerr << "\n[ERROR] Port 8889 is busy! Please close old OyuKu_Server instances." << std::endl;
        }
        else {
            std::cerr << "\n[HATA] 8889 Portu mesgul! Eski OyuKu_Server orneklerini kapatin." << std::endl;
        }
        closesocket(sock);
        return;
    }

    // SIO_UDP_CONNRESET kapatılarak ICMP Port Unreachable hatalarının (10054)
    // WSAPoll ve recvfrom'u bozması engellenir
    DWORD dwBytesReturned = 0;
    BOOL bNewBehavior = FALSE;
    WSAIoctl(sock, SIO_UDP_CONNRESET, &bNewBehavior, sizeof(bNewBehavior), NULL, 0, &dwBytesReturned, NULL, NULL);

    // FAZ 0: WSAPoll ile non-blocking — veri kaybı sıfır, hızlı stop tepkisi
    WSAPOLLFD pfd = {};
    pfd.fd = sock;
    pfd.events = POLLIN;

    char buffer[256];
    sockaddr_in clientAddr;
    int clientAddrLen = sizeof(clientAddr);

    while (!stoken.stop_requested()) {
        int pollResult = WSAPoll(&pfd, 1, 500); // 500ms poll timeout
        if (pollResult > 0 && (pfd.revents & POLLIN)) {
            clientAddrLen = sizeof(clientAddr);
            int bytes = recvfrom(sock, buffer, 255, 0, (sockaddr*)&clientAddr, &clientAddrLen);
            if (bytes > 0) {
                buffer[bytes] = '\0';
                if (std::string(buffer) == "DOYADI_SEARCH") {
                    std::string reply = "DOYADI_PC_OK";
                    sendto(sock, reply.c_str(), (int)reply.length(), 0, (sockaddr*)&clientAddr, clientAddrLen);
                }
            }
        }
        // pollResult == 0 → timeout, döngü devam eder
        // pollResult < 0 → socket hatası (kapanış sırasında olabilir)
        if (pollResult < 0) break;
    }
    closesocket(sock);
}

// 2. THREAD: Wi-Fi ve USB Dinleyici 
// FAZ 0: WSAPoll non-blocking + stop_token — sürüş verisi düşük gecikme
void UdpDataListener(std::stop_token stoken) {
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in serverAddr;
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(UDP_DATA_PORT);
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
        if (appLang == "english" || appLang == "en") {
            std::cerr << "\n[ERROR] Port 8888 is busy! Please close old OyuKu_Server instances." << std::endl;
        }
        else {
            std::cerr << "\n[HATA] 8888 Portu mesgul! Eski OyuKu_Server orneklerini kapatin." << std::endl;
        }
        closesocket(sock);
        return;
    }

    // SIO_UDP_CONNRESET kapatılarak ICMP Port Unreachable hatalarının (10054)
    // WSAPoll ve recvfrom'u bozması engellenir
    DWORD dwBytesReturned = 0;
    BOOL bNewBehavior = FALSE;
    WSAIoctl(sock, SIO_UDP_CONNRESET, &bNewBehavior, sizeof(bNewBehavior), NULL, 0, &dwBytesReturned, NULL, NULL);

    // FAZ 0: WSAPoll ile non-blocking — SO_RCVTIMEO kaldırıldı
    // 100ms poll timeout: sürüş verisi ~16ms (60 FPS) aralıklarla geldiğinden
    // poll genellikle anında döner, timeout sadece veri yokken stop kontrolü için
    WSAPOLLFD pfd = {};
    pfd.fd = sock;
    pfd.events = POLLIN;

    unsigned char buffer[MAX_PACKET_SIZE];
    sockaddr_in clientAddr;
    int clientAddrLen = sizeof(clientAddr);

    if (appLang == "english" || appLang == "en") {
        std::cout << "[WIFI/USB] Searching for OyuKu app (Port: 8889)..." << std::endl;
    }
    else {
        std::cout << "[WIFI/USB] Agda OyuKu uygulamasi araniyor (Port: 8889)..." << std::endl;
    }

    while (!stoken.stop_requested()) {
        int pollResult = WSAPoll(&pfd, 1, 100); // 100ms — düşük gecikme
        if (pollResult > 0 && (pfd.revents & POLLIN)) {
            clientAddrLen = sizeof(clientAddr);
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
        if (pollResult < 0) break;
    }
    closesocket(sock);
}

// Bluetooth Dinleyici
// FAZ 0: WSAPoll non-blocking accept + stop_token + pending tasks takibi
void BluetoothListener(std::stop_token stoken) {
    while (!stoken.stop_requested()) {
        SOCKET bthSock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
        if (bthSock == INVALID_SOCKET) {
            // Bluetooth kapalıysa bekle, ama stop kontrolü ile
            for (int i = 0; i < 30 && !stoken.stop_requested(); i++) Sleep(100);
            continue;
        }

        ULONG auth = 0;
        setsockopt(bthSock, SOL_RFCOMM, SO_BTH_AUTHENTICATE, (char*)&auth, sizeof(auth));

        SOCKADDR_BTH bthAddr = { 0 };
        bthAddr.addressFamily = AF_BTH;
        bthAddr.port = BT_PORT_ANY;

        if (bind(bthSock, (sockaddr*)&bthAddr, sizeof(bthAddr)) == SOCKET_ERROR) {
            closesocket(bthSock);
            for (int i = 0; i < 30 && !stoken.stop_requested(); i++) Sleep(100);
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
        qs.lpszServiceInstanceName = (LPWSTR)L"OyuKu_Server";
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

        // FAZ 0: WSAPoll ile non-blocking accept — blocking accept artık kullanılmıyor
        WSAPOLLFD acceptPfd = {};
        acceptPfd.fd = bthSock;
        acceptPfd.events = POLLIN;

        while (!stoken.stop_requested()) {
            int pollResult = WSAPoll(&acceptPfd, 1, 500); // 500ms poll — hızlı stop kontrolü
            if (pollResult <= 0) {
                if (pollResult < 0) break; // socket hatası
                continue; // timeout, döngü devam
            }

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

                // FAZ 0: Client socket için de WSAPoll kullan — kesintisiz akış
                WSAPOLLFD clientPfd = {};
                clientPfd.fd = clientSock;
                clientPfd.events = POLLIN;

                while (!stoken.stop_requested()) {
                    int clientPoll = WSAPoll(&clientPfd, 1, 100); // 100ms — düşük gecikme
                    if (clientPoll < 0) break; // socket hatası
                    if (clientPoll == 0) continue; // timeout, stop kontrolü

                    int bytes = recv(clientSock, (char*)recvBuf, BT_BUFFER_SIZE, 0);

                    if (bytes == SOCKET_ERROR) {
                        break; // Kopma veya donanım hatası
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
                            // FAZ 0: Fire-and-forget detach yerine takip edilen jthread
                            // Ana BT recv döngüsünü bloklamayacak şekilde ayrı thread'de çalıştır
                            // Böylece DLL'in StartPlugin fonksiyonu uzun sürse bile
                            // sürüş verisi akmaya devam eder.
                            {
                                std::lock_guard<std::mutex> lock(pendingTasksMutex);
                                // Bitmiş task'leri temizle (joinable olmayan = zaten tamamlanmış)
                                std::erase_if(pendingTasks, [](const std::jthread& t) {
                                    return !t.joinable();
                                });
                                pendingTasks.emplace_back([pluginID, turnOn]() {
                                    try {
                                        pluginManager.ProcessCommand(pluginID, turnOn, "BT");
                                    } catch (...) {
                                        std::cerr << "[HATA] BT ProcessCommand exception!" << std::endl;
                                    }
                                });
                            }
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
    SetConsoleTitleA("OyuKu_Server");
    char langBuffer[10];
    GetPrivateProfileStringA("Settings", "Language", "tr", langBuffer, 10, ".\\config.ini");
    appLang = std::string(langBuffer);

    maxClients = GetPrivateProfileIntA("Settings", "MaxClients", 8, ".\\config.ini");
    if (maxClients < 1) maxClients = 1;
    if (maxClients > 8) maxClients = 8;

    if (appLang == "english" || appLang == "en") {
        std::cout << "========================================" << std::endl;
        std::cout << "           OyuKu - PC SERVER            " << std::endl;
        std::cout << "========================================\n" << std::endl;
        std::cout << "[INFO] Dynamic Plug & Play Active (Max: " << maxClients << " Players)" << std::endl;
    }
    else {
        std::cout << "========================================" << std::endl;
        std::cout << "          OyuKu - PC SUNUCUSU           " << std::endl;
        std::cout << "========================================\n" << std::endl;
        std::cout << "[BILGI] Dinamik Tak-Calistir Aktif (Maksimum: " << maxClients << " Oyuncu)" << std::endl;
    }

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

    // Seçilen sayı kadar boş slot hazırla (Kollar telefon bağlandıkça dinamik olarak Windows'a takılır)
    for (int i = 0; i < maxClients; i++) {
        ControllerSlot s;
        s.pad = vigem_target_x360_alloc();
        s.isConnectedToVigem = false;
        slots.push_back(s);
    }

    pluginManager.Init(".\\OyuKu_Ek");

    // FAZ 0: std::jthread — scope sonunda otomatik request_stop() + join()
    // detach() tamamen kaldırıldı, thread sızıntısı artık imkansız
    std::jthread watchdog(WatchdogThread);
    std::jthread udpDiscovery(DiscoveryListener);
    std::jthread udpData(UdpDataListener);
    std::jthread btData(BluetoothListener);

    if (appLang == "english" || appLang == "en") {
        std::cout << ">>> Server is running. Press ENTER to stop... <<<" << std::endl;
    }
    else {
        std::cout << ">>> Sunucu calisiyor. Kapatmak icin ENTER'a basin... <<<" << std::endl;
    }

    std::cin.get();
    isRunning.store(false); // FAZ 0: atomic store

    // FAZ 0: Güvenli Kapanış Sırası
    // 1. Önce dinleyici thread'leri güvenle durdur ve kapanmalarını bekle
    // (Böylece gelen yeni paketler işlenmez ve ViGEm/Slot erişimi tamamen durur)
    btData.request_stop();
    udpData.request_stop();
    udpDiscovery.request_stop();
    watchdog.request_stop();

    if (btData.joinable()) btData.join();
    if (udpData.joinable()) udpData.join();
    if (udpDiscovery.joinable()) udpDiscovery.join();
    if (watchdog.joinable()) watchdog.join();

    // 2. Plugin'leri kapat
    pluginManager.Shutdown();

    // 3. Pending BT ProcessCommand task'lerini bekle
    {
        std::lock_guard<std::mutex> lock(pendingTasksMutex);
        pendingTasks.clear();
    }

    // 4. ViGEm temizliği (Artık hiçbir thread ViGEm'e erişmiyor!)
    for (int i = 0; i < maxClients; i++) {
        if (slots[i].isConnectedToVigem) {
            vigem_target_remove(client, slots[i].pad);
        }
        vigem_target_free(slots[i].pad);
    }

    vigem_disconnect(client);
    vigem_free(client);

    // 5. Winsock temizliği (Artık hiçbir socket açık değil!)
    WSACleanup();
    return 0;
}