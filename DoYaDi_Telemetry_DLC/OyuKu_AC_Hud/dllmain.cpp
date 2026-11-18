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
    int numberOfTyresOut;
    int pitLimiterOn;
    float abs;
    float kersCharge;
    float kersInput;
    int autoShifterOn;
    float rideHeight[2];
    float turboBoost;
    float ballast;
    float airDensity;
    float airTemp;
    float roadTemp;
    float localAngularVel[3];
    float finalFF;
    float performanceMeter;
    int engineBrake;
    int ersRecoveryLevel;
    int ersPowerLevel;
    int ersHeatCharging;
    int ersIsCharging;
    float kersCurrentKJ;
    int drsAvailable;
    int drsEnabled;
    float brakeTemp[4];
    // AC 1.5+ (Shared Memory v1.5+) ek alanları — resmi düzende brakeTemp'ten hemen sonra gelir
    float clutch;
    float tyreTempI[4]; // İç yüzey sıcaklığı (°C)
    float tyreTempM[4]; // Orta yüzey sıcaklığı (°C)
    float tyreTempO[4]; // Dış yüzey sıcaklığı (°C)
};

struct SPageStatic {
    wchar_t smVersion[15];
    wchar_t acVersion[15];
    int numberOfSessions;
    int numCars;
    wchar_t carModel[33];
    wchar_t track[33];
    wchar_t playerName[33];
    wchar_t playerSurname[33];
    wchar_t playerNick[33];
    int sectorCount;
    float maxTorque;
    float maxPower;
    int maxRpm;
    float maxFuel;
    float suspensionMaxTravel[4];
    float tyreRadius[4];
    float maxTurboBoost;
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

    // ── 2. ~60 Hz Telemetri Döngüsü ──
    HANDLE hMapPhysics = NULL;
    HANDLE hMapStatic = NULL;
    bool wasConnected = false;
    int lastGear = 0;
    int maxObservedRPM = 0;

    float prevAccG[3] = { 0.0f, 0.0f, 0.0f };
    bool hasPrevG = false;
    float prevDamageSum = 0.0f;

    while (isRunning) {
        if (hMapPhysics == NULL) {
            hMapPhysics = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Local\\acpmf_physics");
            if (hMapPhysics == NULL) hMapPhysics = OpenFileMappingW(FILE_MAP_READ, FALSE, L"acpmf_physics");
            if (hMapPhysics == NULL) hMapPhysics = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Global\\acpmf_physics");

            if (hMapPhysics != NULL && !wasConnected) {
                wasConnected = true;
                std::cout << "[TELEMETRY DLC] Assetto Corsa Shared Memory baglantisi saglandi! (acpmf_physics)" << std::endl;
            }
        }
        if (hMapStatic == NULL) {
            hMapStatic = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Local\\acpmf_static");
            if (hMapStatic == NULL) hMapStatic = OpenFileMappingW(FILE_MAP_READ, FALSE, L"acpmf_static");
            if (hMapStatic == NULL) hMapStatic = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Global\\acpmf_static");
        }

        unsigned char packet[32] = {};
        packet[0] = 0xFE; // Genişletilmiş Telemetri imzası

        if (hMapPhysics != NULL) {
            SPagePhysics* physics = (SPagePhysics*)MapViewOfFile(hMapPhysics, FILE_MAP_READ, 0, 0, 0);
            SPageStatic* pStatic = (hMapStatic != NULL) ? (SPageStatic*)MapViewOfFile(hMapStatic, FILE_MAP_READ, 0, 0, 0) : NULL;

            if (physics != NULL) {
                // [1] RPM — Arabanın gerçek max RPM'ini statik yapıdan al (F1: 18000, GT3: 8500, Yol: 6500)
                int staticMaxRPM = (pStatic != NULL && pStatic->maxRpm > 1000) ? pStatic->maxRpm : 0;
                if (physics->rpms > maxObservedRPM) {
                    maxObservedRPM = physics->rpms;
                }
                int effectiveMaxRPM = staticMaxRPM > 1000 ? staticMaxRPM : (maxObservedRPM > 4000 ? maxObservedRPM : 8500);

                int rpmNorm = (int)((float)physics->rpms * 255.0f / (float)effectiveMaxRPM);
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

                // [6] DRS (0=kapalı, 1=müsait, 2=aktif)
                if (physics->drs > 0.5f || physics->drsEnabled > 0) {
                    packet[6] = 2; // Aktif
                } else if (physics->drsAvailable > 0) {
                    packet[6] = 1; // Müsait
                } else {
                    packet[6] = 0;
                }

                // [7] ERS (KERS charge 0-1.0f -> 0-255)
                packet[7] = (unsigned char)max(0, min(255, (int)(physics->kersCharge * 255.0f)));

                // [8-11] Lastik Sıcaklıkları (°C doğrudan, 0-255)
                // Oyun içi lastik uygulaması YÜZEY sıcaklığını (İç/Orta/Dış) gösterir.
                // Çekirdek (core) sıcaklık çok yavaş değiştiği için oyundaki değerlerle
                // uyuşmuyordu. Yüzey ortalaması kullanılır; yüzey verisi yoksa (eski
                // AC sürümü) çekirdek sıcaklığa geri düşülür. Sıra: FL, FR, RL, RR.
                for (int i=0; i<4; i++) {
                    float surface = (physics->tyreTempI[i] + physics->tyreTempM[i] + physics->tyreTempO[i]) / 3.0f;
                    float tempC = (surface > 1.0f && surface < 400.0f) ? surface : physics->tyreCoreTemperature[i];
                    int t = (int)round(tempC);
                    packet[8+i] = (unsigned char)max(0, min(255, t));
                }

                // [12-15] Lastik Sağlığı / Kalan Ömür (%0-100)
                // Bazı sürümler 0.0-1.0 ölçeğinde, bazıları 0-100 ölçeğinde verir.
                // 0-1 ölçeği yuvarlanınca %1 (kırmızı) görünüyordu; normalize edilir.
                for (int i=0; i<4; i++) {
                    float rawWear = physics->tyreWear[i];
                    float wearPct = (rawWear > 0.0f && rawWear <= 1.5f) ? rawWear * 100.0f : rawWear;
                    int w = (int)round(wearPct);
                    packet[12+i] = (unsigned char)max(0, min(100, w));
                }

                // [16-17] Slip — Sol taraf (FL+RL) / Sağ taraf (FR+RR)
                float leftSlip = (fabsf(physics->wheelSlip[0]) + fabsf(physics->wheelSlip[2])) / 2.0f;
                float rightSlip = (fabsf(physics->wheelSlip[1]) + fabsf(physics->wheelSlip[3])) / 2.0f;
                packet[16] = (unsigned char)max(0, min(255, (int)(leftSlip * 128.0f)));
                packet[17] = (unsigned char)max(0, min(255, (int)(rightSlip * 128.0f)));

                // [18] Gear Impact
                if (physics->gear != lastGear) {
                    packet[18] = 200;
                    lastGear = physics->gear;
                } else {
                    packet[18] = 0;
                }

                // [19-20] Gerçek Motor Devri (uint16 big-endian, RPM)
                // Araç paketlerinde irtifa alanı kullanılmadığından motor devri buraya
                // yazılır ve flags bit3 (0x08) ile işaretlenir. Uygulama bu bayrağı
                // görünce bu alanı RPM olarak okur.
                int engineRpm = max(0, min(65535, physics->rpms));
                packet[19] = (unsigned char)((engineRpm >> 8) & 0xFF);
                packet[20] = (unsigned char)(engineRpm & 0xFF);

                // [30] Flags: bit 1: absActive, bit 2: tcActive, bit 3: [19-20]=engineRpm
                unsigned char flags = 0x08;
                if (physics->abs > 0.05f) flags |= 0x02;
                if (physics->tc > 0.05f)  flags |= 0x04;
                packet[30] = flags;

                // 32 baytlık paketi gönder
                if (!useBT && sock != INVALID_SOCKET) {
                    sendto(sock, (char*)packet, 32, 0, (sockaddr*)&phoneAddr, sizeof(phoneAddr));
                }

                if (pStatic != NULL) {
                    UnmapViewOfFile(pStatic);
                }
                UnmapViewOfFile(physics);

                // ~60 Hz (16ms)
                std::this_thread::sleep_for(std::chrono::milliseconds(16));
            } else {
                CloseHandle(hMapPhysics);
                hMapPhysics = NULL;
                if (hMapStatic != NULL) {
                    CloseHandle(hMapStatic);
                    hMapStatic = NULL;
                }
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

    if (hMapStatic != NULL) {
        CloseHandle(hMapStatic);
        hMapStatic = NULL;
    }
    if (hMapPhysics != NULL) {
        CloseHandle(hMapPhysics);
        hMapPhysics = NULL;
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