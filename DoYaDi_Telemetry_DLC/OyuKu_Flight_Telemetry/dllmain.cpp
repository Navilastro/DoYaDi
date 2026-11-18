#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <thread>
#include <atomic>
#include <chrono>
#include <string>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <algorithm>

#pragma comment(lib, "ws2_32.lib")

// ─────────────────────────────────────────────────────────────────────────────
// OyuKu Uçuş Telemetri Shared Memory Yapısı
// Harici uçuş simülatörü köprüleri (MSFS / DCS / X-Plane) bu belleğe yazabilir.
// Yerleşik olarak ayrıca War Thunder yerel HTTP API'si (127.0.0.1:8111) okunur.
// ─────────────────────────────────────────────────────────────────────────────
#pragma pack(push, 4)
struct OyuKuFlightSharedMemory {
    unsigned int packetId;
    float altitudeFt;      // 0..65535 ft
    float airspeedKnots;   // IAS knots
    float mach;            // Mach sayısı
    float pitchDeg;        // Yunuslama (-90..+90 derece)
    float rollDeg;         // Yatış (-180..+180 derece)
    float headingDeg;      // Pusula baş açısı (0..360 derece)
    float vsiFpm;          // Dikey hız (ft/min)
    float n1Pct;           // Motor 1 / Ana türbin RPM % (0..110)
    float n2Pct;           // Motor 2 / Çekirdek RPM % (0..110)
    float egtC;            // Egzoz gaz sıcaklığı (°C)
    float fuelPct;         // Kalan yakıt % (0..100)
    float gForce;          // G yükü
    float aoaDeg;          // Hücum açısı (AoA derece)
    float gearPct;         // İniş takımı % (0=yukarı, 100=aşağı)
    float flapsPct;        // Flap % (0..100)
    float airbrakePct;     // Hava freni % (0..100)
    unsigned int flags;    // bit0: stall, bit1: overspeed, bit2: wep, bit3: gearDown
};
#pragma pack(pop)

// ─────────────────────────────────────────────────────────────────────────────
// Global Değişkenler
// ─────────────────────────────────────────────────────────────────────────────
static std::atomic<bool> g_isRunning{false};
static std::thread g_telemetryThread;

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    (void)hModule;
    (void)lpReserved;
    switch (ul_reason_for_call) {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

namespace {
int ClampInt(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// Yerel War Thunder (127.0.0.1:8111) endpoint'inden JSON yanıtı alır
bool FetchLocalHttpGet(const char* path, std::string& outBody) {
    SOCKET tcpSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (tcpSock == INVALID_SOCKET) return false;

    DWORD timeoutMs = 40;
    setsockopt(tcpSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeoutMs, sizeof(timeoutMs));
    setsockopt(tcpSock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&timeoutMs, sizeof(timeoutMs));

    sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(8111);
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

    if (connect(tcpSock, (sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR) {
        closesocket(tcpSock);
        return false;
    }

    std::string req = std::string("GET ") + path +
        " HTTP/1.1\r\nHost: 127.0.0.1:8111\r\nConnection: close\r\n\r\n";
    if (send(tcpSock, req.c_str(), (int)req.size(), 0) == SOCKET_ERROR) {
        closesocket(tcpSock);
        return false;
    }

    std::string raw;
    char buf[2048];
    int received = 0;
    while ((received = recv(tcpSock, buf, sizeof(buf), 0)) > 0) {
        raw.append(buf, received);
        if (raw.size() > 32768) break;
    }
    closesocket(tcpSock);

    size_t bodyPos = raw.find("\r\n\r\n");
    if (bodyPos == std::string::npos) return false;
    outBody = raw.substr(bodyPos + 4);
    return !outBody.empty();
}

bool ExtractJsonNumber(const std::string& json, const char* key, double& outVal) {
    std::string pattern = std::string("\"") + key + "\"";
    size_t pos = json.find(pattern);
    if (pos == std::string::npos) return false;
    pos = json.find(':', pos + pattern.size());
    if (pos == std::string::npos) return false;
    pos++;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) {
        pos++;
    }
    if (pos >= json.size()) return false;
    char* endPtr = nullptr;
    double val = std::strtod(json.c_str() + pos, &endPtr);
    if (endPtr == json.c_str() + pos) return false;
    outVal = val;
    return true;
}

bool ExtractJsonBool(const std::string& json, const char* key, bool& outVal) {
    std::string pattern = std::string("\"") + key + "\"";
    size_t pos = json.find(pattern);
    if (pos == std::string::npos) return false;
    pos = json.find(':', pos + pattern.size());
    if (pos == std::string::npos) return false;
    pos++;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) {
        pos++;
    }
    if (json.compare(pos, 4, "true") == 0) {
        outVal = true;
        return true;
    }
    if (json.compare(pos, 5, "false") == 0) {
        outVal = false;
        return true;
    }
    return false;
}
} // namespace

// ─────────────────────────────────────────────────────────────────────────────
// 32-Byte Extended Telemetry (0xFE) Uçuş Paketi Oluşturma ve UDP Gönderimi
// ─────────────────────────────────────────────────────────────────────────────
void TelemetryLoop(std::string targetIp, int targetPort) {
    std::cout << "[FLIGHT TELEMETRY DLC] OyuKu Ucus Telemetri MFD baslatildi -> "
              << targetIp << ":" << targetPort << std::endl;

    SOCKET sock = INVALID_SOCKET;
    sockaddr_in phoneAddr = {};
    const bool useBT = (targetIp == "BT");

    WSADATA wsaData;
    const bool wsaStarted = (WSAStartup(MAKEWORD(2, 2), &wsaData) == 0);

    if (!useBT && wsaStarted) {
        sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock == INVALID_SOCKET) {
            std::cerr << "[FLIGHT TELEMETRY DLC HATA] UDP soket acilamadi!" << std::endl;
            WSACleanup();
            return;
        }
        phoneAddr.sin_family = AF_INET;
        phoneAddr.sin_port = htons(targetPort);
        inet_pton(AF_INET, targetIp.c_str(), &phoneAddr.sin_addr);
    }

    HANDLE hMapFile = NULL;
    bool shmConnected = false;
    bool wtConnected = false;
    auto lastWtProbe = std::chrono::steady_clock::now() - std::chrono::seconds(2);

    OyuKuFlightSharedMemory liveData = {};

    while (g_isRunning.load()) {
        bool hasLiveSource = false;

        // 1) Önce Shared Memory kaynağı kontrol et (MSFS / DCS / X-Plane köprüleri)
        if (hMapFile == NULL) {
            hMapFile = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Local\\OyuKu_Flight_Telemetry");
            if (hMapFile == NULL) {
                hMapFile = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Global\\OyuKu_Flight_Telemetry");
            }
            if (hMapFile == NULL) {
                hMapFile = OpenFileMappingW(FILE_MAP_READ, FALSE, L"Local\\DoYaDi_Flight_Telemetry");
            }
        }

        if (hMapFile != NULL) {
            const auto* shm = (const OyuKuFlightSharedMemory*)MapViewOfFile(
                hMapFile, FILE_MAP_READ, 0, 0, sizeof(OyuKuFlightSharedMemory));
            if (shm != NULL) {
                if (shm->packetId != 0 || shm->altitudeFt != 0.0f || shm->airspeedKnots != 0.0f) {
                    liveData = *shm;
                    hasLiveSource = true;
                    if (!shmConnected) {
                        shmConnected = true;
                        std::cout << "[FLIGHT TELEMETRY DLC] Shared Memory baglantisi kuruldu." << std::endl;
                    }
                }
                UnmapViewOfFile(shm);
            } else {
                CloseHandle(hMapFile);
                hMapFile = NULL;
                shmConnected = false;
            }
        }

        // 2) Shared Memory yoksa War Thunder localhost API'sini (127.0.0.1:8111) oku
        if (!hasLiveSource && wsaStarted) {
            const auto now = std::chrono::steady_clock::now();
            const long long probeMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                now - lastWtProbe).count();
            // War Thunder açıksa ~20 Hz (50ms), kapalıysa 1 Hz (1000ms) dene
            if (probeMs >= (wtConnected ? 45 : 1000)) {
                lastWtProbe = now;
                std::string stateJson;
                std::string indJson;
                const bool gotState = FetchLocalHttpGet("/state", stateJson);
                const bool gotInd = FetchLocalHttpGet("/indicators", indJson);

                bool validState = false;
                if (gotState) {
                    ExtractJsonBool(stateJson, "valid", validState);
                }

                if (gotState && validState) {
                    double v = 0.0;
                    if (ExtractJsonNumber(stateJson, "H, m", v)) liveData.altitudeFt = (float)(v * 3.28084);
                    if (ExtractJsonNumber(stateJson, "IAS, km/h", v)) liveData.airspeedKnots = (float)(v * 0.539957);
                    else if (ExtractJsonNumber(stateJson, "TAS, km/h", v)) liveData.airspeedKnots = (float)(v * 0.539957);
                    if (ExtractJsonNumber(stateJson, "M", v)) liveData.mach = (float)v;
                    if (ExtractJsonNumber(stateJson, "Vy, m/s", v)) liveData.vsiFpm = (float)(v * 196.8504);
                    if (ExtractJsonNumber(stateJson, "Ny", v)) liveData.gForce = (float)v;
                    if (ExtractJsonNumber(stateJson, "AoA, deg", v)) liveData.aoaDeg = (float)v;
                    if (ExtractJsonNumber(stateJson, "gear, %", v)) liveData.gearPct = (float)v;
                    if (ExtractJsonNumber(stateJson, "flaps, %", v)) liveData.flapsPct = (float)v;
                    if (ExtractJsonNumber(stateJson, "airbrake, %", v)) liveData.airbrakePct = (float)v;

                    double fuelKg = 0.0, maxFuelKg = 0.0;
                    if (ExtractJsonNumber(stateJson, "Mfuel, kg", fuelKg) &&
                        ExtractJsonNumber(stateJson, "Mfuel0, kg", maxFuelKg) && maxFuelKg > 0.1) {
                        liveData.fuelPct = (float)((fuelKg / maxFuelKg) * 100.0);
                    }

                    double thr1 = 0.0;
                    if (ExtractJsonNumber(stateJson, "throttle 1, %", thr1)) {
                        liveData.n1Pct = (float)thr1;
                        if (thr1 > 101.0) liveData.flags |= 0x04;
                        else liveData.flags &= ~0x04u;
                    }
                    double rpm1 = 0.0;
                    if (ExtractJsonNumber(stateJson, "RPM 1", rpm1)) {
                        liveData.n2Pct = (float)ClampInt((int)(rpm1 / 30.0), 0, 100);
                    } else {
                        liveData.n2Pct = liveData.n1Pct;
                    }

                    double waterTemp = 0.0;
                    if (ExtractJsonNumber(stateJson, "water temp 1, C", waterTemp)) {
                        liveData.egtC = (float)(200.0 + waterTemp * 4.0);
                    } else if (ExtractJsonNumber(stateJson, "oil temp 1, C", waterTemp)) {
                        liveData.egtC = (float)(200.0 + waterTemp * 4.5);
                    } else {
                        liveData.egtC = 220.0f + liveData.n1Pct * 5.2f;
                    }

                    if (gotInd) {
                        if (ExtractJsonNumber(indJson, "aviahorizon_pitch", v)) liveData.pitchDeg = (float)v;
                        if (ExtractJsonNumber(indJson, "aviahorizon_roll", v)) liveData.rollDeg = (float)v;
                        if (ExtractJsonNumber(indJson, "compass", v)) liveData.headingDeg = (float)v;
                    }

                    // Uyarı bayrakları
                    if (std::fabs(liveData.aoaDeg) > 18.0f || (liveData.airspeedKnots > 5.0f && liveData.airspeedKnots < 65.0f)) {
                        liveData.flags |= 0x01; // stall
                    } else {
                        liveData.flags &= ~0x01u;
                    }
                    if (liveData.mach > 1.25f || liveData.airspeedKnots > 700.0f) {
                        liveData.flags |= 0x02; // overspeed
                    } else {
                        liveData.flags &= ~0x02u;
                    }
                    if (liveData.gearPct >= 50.0f) liveData.flags |= 0x08;
                    else liveData.flags &= ~0x08u;

                    hasLiveSource = true;
                    if (!wtConnected) {
                        wtConnected = true;
                        std::cout << "[FLIGHT TELEMETRY DLC] War Thunder yerel API (127.0.0.1:8111) baglandi!" << std::endl;
                    }
                } else if (wtConnected) {
                    wtConnected = false;
                    std::cout << "[FLIGHT TELEMETRY DLC] War Thunder baglantisi bekliyor..." << std::endl;
                }
            } else if (wtConnected) {
                hasLiveSource = true;
            }
        }

        // 3) 32-byte 0xFE paketini doldur
        unsigned char packet[32] = {};
        packet[0] = 0xFE;

        if (hasLiveSource || shmConnected || wtConnected) {
            const int altFt = ClampInt((int)std::lround(liveData.altitudeFt), 0, 65535);
            const int iasKts = ClampInt((int)std::lround(liveData.airspeedKnots), 0, 65535);
            const int speedKmhRaw = ClampInt((int)std::lround((liveData.airspeedKnots * 1.852) * 255.0 / 400.0), 0, 255);
            const int n1Norm = ClampInt((int)std::lround(liveData.n1Pct * 255.0f / 100.0f), 0, 255);
            const int n2Norm = ClampInt((int)std::lround(liveData.n2Pct * 255.0f / 100.0f), 0, 255);
            const int egtNorm = ClampInt((int)std::lround((liveData.egtC - 200.0f) * 255.0f / 700.0f), 0, 255);

            int hdg = (int)std::lround(liveData.headingDeg) % 360;
            if (hdg < 0) hdg += 360;
            const int machX100 = ClampInt((int)std::lround(liveData.mach * 100.0f), 0, 255);
            const int fuelPct = ClampInt((int)std::lround(liveData.fuelPct), 0, 100);
            const int gearPct = ClampInt((int)std::lround(liveData.gearPct), 0, 100);
            const int flapsPct = ClampInt((int)std::lround(liveData.flapsPct), 0, 100);
            const int airbrkPct = ClampInt((int)std::lround(liveData.airbrakePct), 0, 100);
            const int gScaled = ClampInt((int)std::lround(liveData.gForce * 10.0f), -127, 127);
            const int aoa = ClampInt((int)std::lround(liveData.aoaDeg), -127, 127);
            const int vsiDiv10 = ClampInt((int)std::lround(liveData.vsiFpm / 10.0f), -32768, 32767);
            const int pitch = ClampInt((int)std::lround(liveData.pitchDeg), -127, 127);
            const int roll = ClampInt((int)std::lround(liveData.rollDeg), -127, 127);

            packet[1] = (unsigned char)n1Norm;
            packet[2] = (unsigned char)speedKmhRaw;
            packet[3] = (unsigned char)gearPct;
            packet[4] = (unsigned char)n1Norm;
            packet[5] = (unsigned char)ClampInt(airbrkPct * 255 / 100, 0, 255);
            packet[6] = (unsigned char)flapsPct;
            packet[7] = (unsigned char)fuelPct;

            // Uçuş özel alanları [8..18] (flags bit7 = 0x80 ile işaretlenir)
            packet[8] = (unsigned char)((hdg >> 8) & 0xFF);
            packet[9] = (unsigned char)(hdg & 0xFF);
            packet[10] = (unsigned char)machX100;
            packet[11] = (unsigned char)fuelPct;
            packet[12] = (unsigned char)gearPct;
            packet[13] = (unsigned char)flapsPct;
            packet[14] = (unsigned char)airbrkPct;
            packet[15] = (unsigned char)((signed char)gScaled);
            packet[16] = (unsigned char)((signed char)aoa);
            packet[17] = (unsigned char)((vsiDiv10 >> 8) & 0xFF);
            packet[18] = (unsigned char)(vsiDiv10 & 0xFF);

            packet[19] = (unsigned char)((altFt >> 8) & 0xFF);
            packet[20] = (unsigned char)(altFt & 0xFF);
            packet[21] = (unsigned char)((iasKts >> 8) & 0xFF);
            packet[22] = (unsigned char)(iasKts & 0xFF);
            packet[23] = (unsigned char)((signed char)pitch);
            packet[24] = (unsigned char)((signed char)roll);
            packet[25] = (unsigned char)n1Norm;
            packet[26] = (unsigned char)n2Norm;
            packet[27] = (unsigned char)egtNorm;

            unsigned char pktFlags = 0x80; // bit7: isFlightPacket
            if ((liveData.flags & 0x01) != 0) pktFlags |= 0x01; // stallWarning
            if ((liveData.flags & 0x02) != 0) pktFlags |= 0x10; // overspeedWarning
            if ((liveData.flags & 0x04) != 0) pktFlags |= 0x20; // wepActive
            if ((liveData.flags & 0x08) != 0 || gearPct >= 50) pktFlags |= 0x40; // gearDown
            packet[30] = pktFlags;
            packet[31] = 0x01; // canli ucus telemetrisi aktif
        } else {
            // Bekleme/hazır paketi (Mod 10 bağlantının canlı olduğunu görsün)
            packet[30] = 0x80; // isFlightPacket
            packet[31] = 0x00;
        }

        if (!useBT && sock != INVALID_SOCKET) {
            sendto(sock, (const char*)packet, 32, 0, (sockaddr*)&phoneAddr, sizeof(phoneAddr));
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(hasLiveSource ? 16 : 250));
    }

    if (hMapFile != NULL) {
        CloseHandle(hMapFile);
        hMapFile = NULL;
    }
    if (sock != INVALID_SOCKET) {
        closesocket(sock);
        sock = INVALID_SOCKET;
    }
    if (wsaStarted) {
        WSACleanup();
    }
    std::cout << "[FLIGHT TELEMETRY DLC] OyuKu Ucus Telemetri MFD temizce kapatildi." << std::endl;
}

// ─────────────────────────────────────────────────────────────────────────────
// OyuKu PluginManager Standart C Arayüzü
// ─────────────────────────────────────────────────────────────────────────────
extern "C" {
    __declspec(dllexport) const char* GetPluginInfo() {
        return "Flight Telemetry MFD (War Thunder / Sim)";
    }

    __declspec(dllexport) int GetPluginID() {
        return 102;
    }

    __declspec(dllexport) const char* GetCategory() {
        return "telemetry";
    }

    __declspec(dllexport) void StartPlugin(const char* phoneIp, int phonePort) {
        (void)phonePort;
        if (!g_isRunning.load()) {
            g_isRunning.store(true);
            g_telemetryThread = std::thread(TelemetryLoop, std::string(phoneIp), 8892);
        }
    }

    __declspec(dllexport) void StopPlugin() {
        if (g_isRunning.load()) {
            g_isRunning.store(false);
            if (g_telemetryThread.joinable()) {
                g_telemetryThread.join();
            }
        }
    }
}
