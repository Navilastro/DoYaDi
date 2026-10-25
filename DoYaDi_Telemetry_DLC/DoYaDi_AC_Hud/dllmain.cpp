#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <thread>
#include <chrono>
#include <string>
#include <cmath>

#pragma comment(lib, "ws2_32.lib")

// ─────────────────────────────────────────────────────────────────────────────
// Assetto Corsa Shared Memory Yapısı
// ─────────────────────────────────────────────────────────────────────────────
#pragma pack(push, 4)
struct SPagePhysics {
    int packetId;
    float gas;
    float brake;
    float fuel;
    int gear;
    int rpms;
    float steerAngle;
    float speedKmh;
    float velocity[3];
    float accG[3];
    float wheelSlip[4];
    float wheelLoad[4];
    float wheelsPressure[4];
    float wheelAngularSpeed[4];
    float tyreWear[4];
    float tyreDirtyLevel[4];
    float tyreCoreTemperature[4];
    float camberRAD[4];
    float suspensionTravel[4];
    float drs;
    float tc;
    float heading;
    float pitch;
    float roll;
    float cgHeight;
    float carDamage[5];
};
#pragma pack(pop)

// ─────────────────────────────────────────────────────────────────────────────
// Global Değişkenler
// ─────────────────────────────────────────────────────────────────────────────
bool isRunning = false;
std::thread telemetryThread;

// ─────────────────────────────────────────────────────────────────────────────
// Windows DLL Giriş Noktası (DllMain)
// ─────────────────────────────────────────────────────────────────────────────
BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    switch (ul_reason_for_call) {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

#include <iostream>

// Telemetri döngüsü — hedef oyunun Shared Memory'sinden veri okur,
// 8 byte'lık protokole çevirir ve UDP ile telefona gönderir.
void TelemetryLoop(std::string targetIp, int targetPort) {
    std::cout << "[TELEMETRY DLC] Assetto Corsa Telemetri dongusu baslatildi -> " 
              << targetIp << ":" << targetPort << std::endl;

    // ── 1. UDP Soket Aç ──
    SOCKET sock = INVALID_SOCKET;
    sockaddr_in phoneAddr = {};

    bool useBT = (targetIp == "BT");

    if (!useBT) {
        WSADATA wsaData;
        WSAStartup(MAKEWORD(2, 2), &wsaData);

        sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock == INVALID_SOCKET) {
            std::cerr << "[TELEMETRY DLC HATA] UDP soket acilamadi!" << std::endl;
            return;
        }

        phoneAddr.sin_family = AF_INET;
        phoneAddr.sin_port = htons(targetPort);
        inet_pton(AF_INET, targetIp.c_str(), &phoneAddr.sin_addr);
    }

    // ── 2. ~30 Hz Telemetri Döngüsü ──
    HANDLE hMapFile = NULL;
    bool wasConnected = false;
    int lastGear = 0;
    const int maxRPM = 9000;

    float prevAccG[3] = { 0.0f, 0.0f, 0.0f };
    bool hasPrevG = false;
    float prevDamageSum = 0.0f;

    while (isRunning) {
        if (hMapFile == NULL) {
            hMapFile = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Local\\acpmf_physics");
            if (hMapFile == NULL) {
                hMapFile = OpenFileMappingW(FILE_MAP_READ, FALSE, L"acpmf_physics");
            }
            if (hMapFile == NULL) {
                hMapFile = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Global\\acpmf_physics");
            }

            if (hMapFile != NULL && !wasConnected) {
                wasConnected = true;
                std::cout << "[TELEMETRY DLC] Assetto Corsa Shared Memory baglantisi saglandi! (acpmf_physics)" << std::endl;
            }
        }

        unsigned char packet[32] = {};
        packet[0] = 0xFE; // Genişletilmiş Telemetri imzası

        if (hMapFile != NULL) {
            SPagePhysics* physics = (SPagePhysics*)MapViewOfFile(hMapFile, FILE_MAP_READ, 0, 0, 0);

            if (physics != NULL) {
                // [1] RPM
                int rpmNorm = (int)((float)physics->rpms * 255.0f / (float)maxRPM);
                packet[1] = (unsigned char)max(0, min(255, rpmNorm));

                // [2] Hız
                int speedNorm = (int)(physics->speedKmh * 255.0f / 400.0f);
                packet[2] = (unsigned char)max(0, min(255, speedNorm));

                // [3] Vites (R=255, N=0, 1-8)
                packet[3] = (unsigned char)(physics->gear - 1); 

                // [4] Gaz
                packet[4] = (unsigned char)(physics->gas * 255.0f);

                // [5] Fren
                packet[5] = (unsigned char)(physics->brake * 255.0f);

                // [6] DRS
                packet[6] = (unsigned char)(physics->drs);

                // [7] ERS (AC'de KERS, fuel veya 0 olarak basıyoruz)
                packet[7] = 0;

                // [8-11] Lastik Sıcaklıkları (0-255 → 0-200°C diyelim)
                for (int i=0; i<4; i++) {
                    int t = (int)(physics->tyreCoreTemperature[i] * 255.0f / 200.0f);
                    packet[8+i] = (unsigned char)max(0, min(255, t));
                }

                // [12-15] Lastik Aşınması (0-100)
                for (int i=0; i<4; i++) {
                    int w = (int)(physics->tyreWear[i]);
                    packet[12+i] = (unsigned char)max(0, min(100, w));
                }

                // [16-17] Slip
                float leftSlip = (fabsf(physics->wheelSlip[0]) + fabsf(physics->wheelSlip[1])) / 2.0f;
                float rightSlip = (fabsf(physics->wheelSlip[2]) + fabsf(physics->wheelSlip[3])) / 2.0f;
                packet[16] = (unsigned char)max(0, min(255, (int)(leftSlip * 128.0f)));
                packet[17] = (unsigned char)max(0, min(255, (int)(rightSlip * 128.0f)));

                // [18] Gear Impact
                if (physics->gear != lastGear) {
                    packet[18] = 200;
                    lastGear = physics->gear;
                } else {
                    packet[18] = 0;
                }

                // 32 baytlık paketi gönder
                if (!useBT && sock != INVALID_SOCKET) {
                    sendto(sock, (char*)packet, 32, 0, (sockaddr*)&phoneAddr, sizeof(phoneAddr));
                }

                UnmapViewOfFile(physics);

                // ~60 Hz (16ms)
                std::this_thread::sleep_for(std::chrono::milliseconds(16));
            } else {
                CloseHandle(hMapFile);
                hMapFile = NULL;
                if (wasConnected) {
                    wasConnected = false;
                    std::cout << "[TELEMETRY DLC] Assetto Corsa Shared Memory baglantisi kesildi." << std::endl;
                }
            }
        } else {
            // Oyun henüz kapalı/beklemede: Telefon ve sunucuya 1 Hz bekleme paketi gönder
            if (!useBT && sock != INVALID_SOCKET) {
                sendto(sock, (char*)packet, 32, 0, (sockaddr*)&phoneAddr, sizeof(phoneAddr));
            }

            // 1 saniyelik beklemeyi 50ms dilimlerle yap ki StopPlugin anında tepki versin
            for (int i = 0; i < 20 && isRunning; i++) {
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
            }
        }
    }

    if (hMapFile != NULL) {
        CloseHandle(hMapFile);
        hMapFile = NULL;
    }
    if (sock != INVALID_SOCKET) {
        closesocket(sock);
        sock = INVALID_SOCKET;
        WSACleanup();
    }
    std::cout << "[TELEMETRY DLC] Telemetri dongusu ve kaynaklar temizce sonlandirildi." << std::endl;
}

// ─────────────────────────────────────────────────────────────────────────────
// DLL Standart Arayüzü — PluginManager bu fonksiyonları çağırır
// ─────────────────────────────────────────────────────────────────────────────
extern "C" {
    /// Eklentinin okunabilir ismi
    __declspec(dllexport) const char* GetPluginInfo() {
        return "Assetto Corsa Hud";
    }

    /// Sayısal kimlik (1-255 arası, her eklenti için benzersiz)
    __declspec(dllexport) int GetPluginID() {
        return 101; // Assetto Corsa Hud = ID 101
    }

    /// Eklenti kategorisi: "haptic", "visual" veya "telemetry"
    __declspec(dllexport) const char* GetCategory() {
        return "telemetry";
    }

    /// Eklentiyi başlat — telefon IP ve portunu alır, telemetri göndermeye başlar.
    /// PluginManager tarafından [0xEE, ID, 0x01] komutu geldiğinde çağrılır.
    __declspec(dllexport) void StartPlugin(const char* phoneIp, int phonePort) {
        if (!isRunning) {
            isRunning = true;
            telemetryThread = std::thread(TelemetryLoop,
                std::string(phoneIp), 8892);
        }
    }

    /// Eklentiyi durdur — telemetri göndermeyi bırakır, kaynakları serbest bırakır.
    /// PluginManager tarafından [0xEE, ID, 0x00] komutu geldiğinde
    /// veya Addon Watchdog timeout'unda çağrılır.
    __declspec(dllexport) void StopPlugin() {
        if (isRunning) {
            isRunning = false;
            if (telemetryThread.joinable()) {
                telemetryThread.join();
            }
        }
    }
}