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

#pragma comment(lib, "ws2_32.lib")      
#pragma comment(lib, "setupapi.lib")    
#pragma comment(lib, "ViGEmClient.lib") 

// Bluetooth Seri Port (SPP) UUID: 00001101-0000-1000-8000-00805F9B34FB
DEFINE_GUID(DoYaDi_SPP_UUID, 0x00001101, 0x0000, 0x1000, 0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb);

#define UDP_DATA_PORT 8888      
#define UDP_DISCOVERY_PORT 8889 
#define MAX_PACKET_SIZE 16

bool isRunning = true;
std::mutex vigemMutex;
PVIGEM_CLIENT client = nullptr;
PVIGEM_TARGET pad = nullptr;

// Global Dil Değişkeni (Varsayılan: tr)
std::string appLang = "tr";

// Ortak XInput Güncelleme Fonksiyonu
void UpdateGamepad(unsigned char* buffer, int bytesReceived, const char* source) {
    std::lock_guard<std::mutex> lock(vigemMutex);
    XUSB_REPORT report;
    XUSB_REPORT_INIT(&report);
    static int lastMouseClick = 0;
    static std::vector<int> lastKeys;
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
        if (currentMouseClick != lastMouseClick) {
            INPUT clickInput = { 0 };
            clickInput.type = INPUT_MOUSE;

            // Eğer yeni gelen 1 ise Sol Tık basıldı, eski 1 yeni 0 ise Sol Tık bırakıldı
            if (currentMouseClick == 1) clickInput.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
            else if (lastMouseClick == 1) clickInput.mi.dwFlags = MOUSEEVENTF_LEFTUP;

            if (currentMouseClick == 2) clickInput.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
            else if (lastMouseClick == 2) clickInput.mi.dwFlags = MOUSEEVENTF_RIGHTUP;

            if (currentMouseClick == 3) clickInput.mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
            else if (lastMouseClick == 3) clickInput.mi.dwFlags = MOUSEEVENTF_MIDDLEUP;

            SendInput(1, &clickInput, sizeof(INPUT));
            lastMouseClick = currentMouseClick;
        }

        // --- 3. KLAVYE ANTI-GHOSTING (Byte 12-15) ---
        std::vector<int> currentKeys;
        for (int i = 12; i <= 15; i++) {
            if (buffer[i] != 0) {
                currentKeys.push_back(buffer[i]); // Basılı olan tuşları listeye al
            }
        }

        // Bırakılan Tuşları Bul (Eski listede var, yeni listede yoksa bırakılmıştır)
        for (int oldKey : lastKeys) {
            if (std::find(currentKeys.begin(), currentKeys.end(), oldKey) == currentKeys.end()) {
                INPUT keyUpInput = { 0 };
                keyUpInput.type = INPUT_KEYBOARD;
                keyUpInput.ki.wVk = oldKey;
                keyUpInput.ki.dwFlags = KEYEVENTF_KEYUP;
                SendInput(1, &keyUpInput, sizeof(INPUT));
            }
        }

        // Yeni Basılan Tuşları Bul (Yeni listede var, eski listede yoksa yeni basılmıştır)
        for (int newKey : currentKeys) {
            if (std::find(lastKeys.begin(), lastKeys.end(), newKey) == lastKeys.end()) {
                INPUT keyDownInput = { 0 };
                keyDownInput.type = INPUT_KEYBOARD;
                keyDownInput.ki.wVk = newKey;
                keyDownInput.ki.dwFlags = 0; // 0 = Basılı tut
                SendInput(1, &keyDownInput, sizeof(INPUT));
            }
        }

        lastKeys = currentKeys; // Hafızayı güncelle
    }

    
    vigem_target_x360_update(client, pad, report);
}

// 1. THREAD: Cihaz Keşfi 
void DiscoveryListener() {
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in serverAddr = { 0 };
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(UDP_DISCOVERY_PORT);
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    // PORT DOLU MU DİYE KONTROL EDİYORUZ
    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
		if (appLang == "english" || appLang == "en") {
            std::cerr << "\n[ERROR] Port 8889 is busy! Please close old DoYaDi instances from Task Manager." << std::endl;
        }
        else {
            std::cerr << "\n[HATA] 8889 Portu mesgul! Gorev Yoneticisinden eski DoYaDi'leri kapatin." << std::endl;
        }
        closesocket(sock);
        return;
    }
    bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr));

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

// 2. THREAD: Wi-Fi Dinleyici 
void UdpDataListener() {
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sockaddr_in serverAddr;
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(UDP_DATA_PORT);
    serverAddr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
		if (appLang == "english" || appLang == "en") {
            std::cerr << "\n[ERROR] Port 8888 is busy! Please close old DoYaDi instances from Task Manager." << std::endl;
        }
        else {
            std::cerr << "\n[HATA] 8888 Portu mesgul! Gorev Yoneticisinden eski DoYaDi'leri kapatin." << std::endl;
        }
        closesocket(sock);
        return;
    }

    // 500ms Zaman Aşımı (Güvenlik Freni)
    DWORD timeout = 500;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

    unsigned char buffer[MAX_PACKET_SIZE];
    sockaddr_in clientAddr;
    int clientAddrLen = sizeof(clientAddr);
	if (appLang == "english" || appLang == "en") {
        std::cout << "[WIFI] Searching for DoYaDi app (Port: 8889)..." << std::endl;
    }
    else {
        std::cout << "[WIFI] Agda DoYaDi uygulamasi araniyor (Port: 8889)..." << std::endl;
    }
    bool isWifiActive = false;
    while (isRunning) {
        int bytes = recvfrom(sock, (char*)buffer, MAX_PACKET_SIZE, 0, (sockaddr*)&clientAddr, &clientAddrLen);
        if (bytes == SOCKET_ERROR) {
            int err = WSAGetLastError();
            if (err == WSAETIMEDOUT) {
                // Bağlantı koptu: Güvenlik paketi gönder (Direksiyon merkez, diğerleri sıfır)
                if (isWifiActive) {
					if (appLang == "english" || appLang == "en") {
                        std::cerr << "[WIFI] Connection lost. Sending safety packet..." << std::endl;
                    }
                    else {
                        std::cerr << "[WIFI] Baglantı koptu. Güvenlik paketi gönderiliyor..." << std::endl;
                    }
                    unsigned char safe_buffer[5] = { 128, 0, 0, 0, 0 };
                    UpdateGamepad(safe_buffer, 5, "WIFI");
					isWifiActive = false;
                }
            }
        }
        else if (bytes == 5 || bytes == 9 || bytes == 16) {
            isWifiActive = true;
            UpdateGamepad(buffer, bytes, "WIFI");
        }
    }
    closesocket(sock);
}

// 3. THREAD: Geliştirilmiş Bluetooth Dinleyici
void BluetoothListener() {
    SOCKET bthSock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (bthSock == INVALID_SOCKET) {
		if (appLang == "english" || appLang == "en") {
            std::cerr << "[BLUETOOTH] Bluetooth hardware not found." << std::endl;
        }
        else {
            std::cerr << "[BLUETOOTH] Bluetooth donanimi bulunamadi." << std::endl;
        }
        return;
    }

    // Güvenlik ayarlarını esnet
    ULONG auth = 0;
    setsockopt(bthSock, SOL_RFCOMM, SO_BTH_AUTHENTICATE, (char*)&auth, sizeof(auth));

    SOCKADDR_BTH bthAddr = { 0 };
    bthAddr.addressFamily = AF_BTH;
    bthAddr.port = BT_PORT_ANY;

    if (bind(bthSock, (sockaddr*)&bthAddr, sizeof(bthAddr)) == SOCKET_ERROR) {
		if (appLang == "english" || appLang == "en") {
            std::cerr << "[BLUETOOTH] Bind error!" << std::endl;
        }
        else {
            std::cerr << "[BLUETOOTH] Bind hatasi!" << std::endl;
        }
        closesocket(bthSock);
        return;
    }

    // SDP Kaydı
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

    if (WSASetService(&qs, RNRSERVICE_REGISTER, 0) == SOCKET_ERROR) {
		if (appLang == "english" || appLang == "en") {
            std::cerr << "[BLUETOOTH] SDP Service registration failed!" << std::endl;
        }
        else {
            std::cerr << "[BLUETOOTH] SDP Servis kaydi basarisiz!" << std::endl;
        }
    }
    else {
		if (appLang == "english" || appLang == "en") {
            std::cout << "[BLUETOOTH] SDP Service registered, waiting for connection..." << std::endl;
        }
        else {
            std::cout << "[BLUETOOTH] SDP Servisi kaydedildi, baglanti bekleniyor..." << std::endl;
        }
    }

    listen(bthSock, 1);

    bool isBthActive = false;
    
    while (isRunning) {
        SOCKADDR_BTH clientAddr;
        int clientAddrLen = sizeof(clientAddr);
        SOCKET clientSock = accept(bthSock, (sockaddr*)&clientAddr, &clientAddrLen);

        if (clientSock != INVALID_SOCKET) {
            if(appLang== "english" || appLang == "en") {
                std::cout << "\n[BLUETOOTH] Phone connected!" << std::endl;
            }
            else {
                std::cout << "\n[BLUETOOTH] Telefon baglandi!" << std::endl;
            }
            unsigned char buffer[MAX_PACKET_SIZE];

            // 500ms Zaman Aşımı (Güvenlik Freni)
            DWORD timeout = 500;
            setsockopt(clientSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

            while (isRunning) {
                int bytes = recv(clientSock, (char*)buffer, MAX_PACKET_SIZE, 0);

                if (bytes == SOCKET_ERROR) {
                    int err = WSAGetLastError();
                    if (err == WSAETIMEDOUT) {
                        if (isBthActive) {
                            unsigned char safe_buffer[5] = { 128, 0, 0, 0, 0 };
                            UpdateGamepad(safe_buffer, 5, "BTH ");
                            isBthActive = false;
                        }
                    }
                    else {
						if (appLang == "english" || appLang == "en") {
                            std::cout << "\n[BLUETOOTH] Connection lost or error." << std::endl;
                        }
                        else {
                            std::cout << "\n[BLUETOOTH] Baglanti koptu veya hata." << std::endl;
                        }
                        break;
                    }
                }
                else if (bytes == 5 || bytes == 9 || bytes == 16) {
					isBthActive = true;
                    UpdateGamepad(buffer, bytes, "BTH ");
                }
                else if (bytes == 0) {
					if (appLang == "english" || appLang == "en") {
                        std::cout << "\n[BLUETOOTH] Connection closed by client." << std::endl;
                    }
                    else {
                        std::cout << "\n[BLUETOOTH] Baglanti kapatildi." << std::endl;
                    }
                    break;
                }
            }
            closesocket(clientSock);
        }
    }

    // Çıkışta SDP kaydını sil
    WSASetService(&qs, RNRSERVICE_DEREGISTER, 0);
    closesocket(bthSock);
}

int main() {
    char langBuffer[10];
    GetPrivateProfileStringA("Settings", "Language", "tr", langBuffer, 10, ".\\config.ini");
    appLang = std::string(langBuffer);

    // 2. Dolaşımdaki konsol yazılarını dile göre bas
    if (appLang == "english" || appLang == "en") {
        std::cout << "========================================" << std::endl;
        std::cout << "          DoYaDi - PC SERVER            " << std::endl;
        std::cout << "========================================\n" << std::endl;
    }
    else {
        std::cout << "========================================" << std::endl;
        std::cout << "         DoYaDi - PC SUNUCUSU           " << std::endl;
        std::cout << "========================================\n" << std::endl;
    }

    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    client = vigem_alloc();
    const auto retval = vigem_connect(client);

    if (!VIGEM_SUCCESS(retval)) {
		if (appLang == "english" || appLang == "en") {
            std::cerr << "[ERROR] ViGEmBus Driver not found or connection error!" << std::endl;
            std::cerr << "Please install Nefarius ViGEmBus Driver on your computer." << std::endl;
        }
    else {
        std::cerr << "[HATA] ViGEmBus Surucusu bulunamadi veya baglanti hatasi!" << std::endl;
        std::cerr << "Lutfen bilgisayariniza Nefarius ViGEmBus Driver kurun." << std::endl;
    }

        system("pause");
        return -1;
    }

    pad = vigem_target_x360_alloc();
    vigem_target_add(client, pad);
	if (appLang == "english" || appLang == "en") {
        std::cout << "[SYSTEM] Virtual Xbox 360 controller is active." << std::endl;
    }
    else {
        std::cout << "[SISTEM] Sanal Xbox 360 kontrolcusu aktif." << std::endl;
    }

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

    vigem_target_remove(client, pad);
    vigem_target_free(pad);
    vigem_disconnect(client);
    vigem_free(client);
    WSACleanup();

    udpDiscovery.detach();
    udpData.detach();
    btData.detach();

    return 0;
}