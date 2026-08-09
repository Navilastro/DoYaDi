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

        unsigned char packet[8] = {};
        packet[0] = 0xFF; // Telemetri imzası

        if (hMapFile != NULL) {
            SPagePhysics* physics = (SPagePhysics*)MapViewOfFile(hMapFile, FILE_MAP_READ, 0, 0, 0);

            if (physics != NULL) {
                // RPM → 0-255 normalize
                int rpmNorm = (int)((float)physics->rpms * 255.0f / (float)maxRPM);
                if (rpmNorm > 255) rpmNorm = 255;
                if (rpmNorm < 0) rpmNorm = 0;
                packet[1] = (unsigned char)rpmNorm;

                // Sol tekerlek kayması (0 ve 1 numaralı tekerleklerin ortalaması)
                float leftSlip = (fabsf(physics->wheelSlip[0]) + fabsf(physics->wheelSlip[1])) / 2.0f;
                int leftVal = (int)(leftSlip * 128.0f);
                if (leftVal > 255) leftVal = 255;
                if (leftVal < 0) leftVal = 0;
                packet[2] = (unsigned char)leftVal;

                // Sağ tekerlek kayması (2 ve 3 numaralı tekerleklerin ortalaması)
                float rightSlip = (fabsf(physics->wheelSlip[2]) + fabsf(physics->wheelSlip[3])) / 2.0f;
                int rightVal = (int)(rightSlip * 128.0f);
                if (rightVal > 255) rightVal = 255;
                if (rightVal < 0) rightVal = 0;
                packet[3] = (unsigned char)rightVal;

                // Vites darbesi — değişim anında 200, yoksa 0
                if (physics->gear != lastGear) {
                    packet[4] = 200;
                    lastGear = physics->gear;
                } else {
                    packet[4] = 0;
                }

                // Kaza / Çarpışma Tespiti (G-Kuvveti Ani Sıçraması & Hasar Artışı)
                unsigned char crashImpact = 0;
                if (hasPrevG) {
                    float dG0 = physics->accG[0] - prevAccG[0];
                    float dG1 = physics->accG[1] - prevAccG[1];
                    float dG2 = physics->accG[2] - prevAccG[2];
                    float gDelta = sqrtf(dG0 * dG0 + dG1 * dG1 + dG2 * dG2);

                    float currentDamageSum = physics->carDamage[0] + physics->carDamage[1] + 
                                             physics->carDamage[2] + physics->carDamage[3] + 
                                             physics->carDamage[4];
                    float damageDelta = currentDamageSum - prevDamageSum;

                    if (gDelta >= 4.5f || damageDelta >= 5.0f) {
                        crashImpact = 255; // Şiddetli Kaza
                    } else if (gDelta >= 2.8f || damageDelta > 0.5f) {
                        crashImpact = 160; // Orta Çarpışma / Darbe
                    }
                    prevDamageSum = currentDamageSum;
                }
                prevAccG[0] = physics->accG[0];
                prevAccG[1] = physics->accG[1];
                prevAccG[2] = physics->accG[2];
                hasPrevG = true;

                packet[5] = crashImpact; // Çarpışma / Kaza darbesi

                if (!useBT && sock != INVALID_SOCKET) {
                    sendto(sock, (char*)packet, 8, 0, (sockaddr*)&phoneAddr, sizeof(phoneAddr));
                }

                UnmapViewOfFile(physics);

                // Oyun açıkken ~30 Hz (33ms)
                std::this_thread::sleep_for(std::chrono::milliseconds(33));
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
            packet[1] = 0;
            packet[2] = 0;
            packet[3] = 0;
            packet[4] = 0;
            packet[5] = 0;
            packet[6] = 0x01; // Bekleme durumu göstergesi

            if (!useBT && sock != INVALID_SOCKET) {
                sendto(sock, (char*)packet, 8, 0, (sockaddr*)&phoneAddr, sizeof(phoneAddr));
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
        return "Assetto Corsa Haptic";
    }

    /// Sayısal kimlik (1-255 arası, her eklenti için benzersiz)
    __declspec(dllexport) int GetPluginID() {
        return 1; // Assetto Corsa = ID 1
    }

    /// Eklenti kategorisi: "haptic", "visual" veya "telemetry"
    __declspec(dllexport) const char* GetCategory() {
        return "haptic";
    }

    /// Eklentiyi başlat — telefon IP ve portunu alır, telemetri göndermeye başlar.
    /// PluginManager tarafından [0xEE, ID, 0x01] komutu geldiğinde çağrılır.
    __declspec(dllexport) void StartPlugin(const char* phoneIp, int phonePort) {
        if (!isRunning) {
            isRunning = true;
            telemetryThread = std::thread(TelemetryLoop,
                std::string(phoneIp), phonePort);
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