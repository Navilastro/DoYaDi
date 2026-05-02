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

// Ortak XInput Güncelleme Fonksiyonu
void UpdateGamepad(unsigned char* buffer, int bytesReceived, const char* source) {
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

    std::lock_guard<std::mutex> lock(vigemMutex);
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
        std::cerr << "\n[HATA] 8889 Portu mesgul! Gorev Yoneticisinden eski DoYaDi'leri kapatin." << std::endl;
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
        std::cerr << "\n[HATA] 8888 Portu mesgul! Gorev Yoneticisinden eski DoYaDi'leri kapatin." << std::endl;
        closesocket(sock);
        return;
    }
    bind(sock, (sockaddr*)&serverAddr, sizeof(serverAddr));

    // 500ms Zaman Aşımı (Güvenlik Freni)
    DWORD timeout = 500;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

    unsigned char buffer[MAX_PACKET_SIZE];
    sockaddr_in clientAddr;
    int clientAddrLen = sizeof(clientAddr);
    std::cout << "[WIFI] Agda DoYaDi uygulamasi araniyor (Port: 8889)..." << std::endl;

    while (isRunning) {
        int bytes = recvfrom(sock, (char*)buffer, MAX_PACKET_SIZE, 0, (sockaddr*)&clientAddr, &clientAddrLen);

        if (bytes == SOCKET_ERROR) {
            int err = WSAGetLastError();
            if (err == WSAETIMEDOUT) {
                // Bağlantı koptu: Güvenlik paketi gönder (Direksiyon merkez, diğerleri sıfır)
                unsigned char safe_buffer[5] = { 128, 0, 0, 0, 0 };
                UpdateGamepad(safe_buffer, 5, "WIFI");
            }
        }
        else if (bytes == 5 || bytes == 9) {
            UpdateGamepad(buffer, bytes, "WIFI");
        }
    }
    closesocket(sock);
}

// 3. THREAD: Geliştirilmiş Bluetooth Dinleyici
void BluetoothListener() {
    SOCKET bthSock = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (bthSock == INVALID_SOCKET) {
        std::cerr << "[BLUETOOTH] Bluetooth donanimi bulunamadi." << std::endl;
        return;
    }

    // Güvenlik ayarlarını esnet
    ULONG auth = 0;
    setsockopt(bthSock, SOL_RFCOMM, SO_BTH_AUTHENTICATE, (char*)&auth, sizeof(auth));

    SOCKADDR_BTH bthAddr = { 0 };
    bthAddr.addressFamily = AF_BTH;
    bthAddr.port = BT_PORT_ANY;

    if (bind(bthSock, (sockaddr*)&bthAddr, sizeof(bthAddr)) == SOCKET_ERROR) {
        std::cerr << "[BLUETOOTH] Bind hatasi!" << std::endl;
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
        std::cerr << "[BLUETOOTH] SDP Servis kaydi basarisiz!" << std::endl;
    }
    else {
        std::cout << "[BLUETOOTH] SDP Servisi kaydedildi, baglanti bekleniyor..." << std::endl;
    }

    listen(bthSock, 1);

    while (isRunning) {
        SOCKADDR_BTH clientAddr;
        int clientAddrLen = sizeof(clientAddr);
        SOCKET clientSock = accept(bthSock, (sockaddr*)&clientAddr, &clientAddrLen);

        if (clientSock != INVALID_SOCKET) {
            std::cout << "\n[BLUETOOTH] Telefon baglandi!" << std::endl;
            unsigned char buffer[MAX_PACKET_SIZE];

            // 500ms Zaman Aşımı (Güvenlik Freni)
            DWORD timeout = 500;
            setsockopt(clientSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

            while (isRunning) {
                int bytes = recv(clientSock, (char*)buffer, MAX_PACKET_SIZE, 0);

                if (bytes == SOCKET_ERROR) {
                    int err = WSAGetLastError();
                    if (err == WSAETIMEDOUT) {
                        unsigned char safe_buffer[5] = { 128, 0, 0, 0, 0 };
                        UpdateGamepad(safe_buffer, 5, "BTH ");
                    }
                    else {
                        std::cout << "\n[BLUETOOTH] Baglanti koptu veya hata." << std::endl;
                        break;
                    }
                }
                else if (bytes >= 5) {
                    UpdateGamepad(buffer, bytes, "BTH ");
                }
                else if (bytes == 0) {
                    std::cout << "\n[BLUETOOTH] Baglanti kapatildi." << std::endl;
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
    std::cout << "========================================" << std::endl;
    std::cout << "         DoYaDi - PC SUNUCUSU           " << std::endl;
    std::cout << "========================================\n" << std::endl;

    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);

    client = vigem_alloc();
    const auto retval = vigem_connect(client);

    if (!VIGEM_SUCCESS(retval)) {
        std::cerr << "[HATA] ViGEmBus Surucusu bulunamadi veya baglanti hatasi!" << std::endl;
        std::cerr << "Lutfen bilgisayariniza Nefarius ViGEmBus Driver kurun." << std::endl;

        system("pause");
        return -1;
    }

    pad = vigem_target_x360_alloc();
    vigem_target_add(client, pad);
    std::cout << "[SISTEM] Sanal Xbox 360 kontrolcusu aktif." << std::endl;

    std::thread udpDiscovery(DiscoveryListener);
    std::thread udpData(UdpDataListener);
    std::thread btData(BluetoothListener);

    std::cout << ">>> Sunucu calisiyor. Kapatmak icin ENTER'a basin... <<<" << std::endl;

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