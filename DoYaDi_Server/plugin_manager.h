#pragma once
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <vector>
#include <string>
#include <thread>
#include <mutex>
#include <filesystem>
#include <chrono>
#include <set>

// ── DLL Standart Fonksiyon Tipleri ──────────────────────────────────────────
// Zorunlu: GetPluginInfo, StartPlugin, StopPlugin
// Opsiyonel: GetPluginID, GetCategory (yoksa varsayılan değer kullanılır)
typedef const char* (*GetInfoFunc)();                            // Zorunlu: Eklenti ismi
typedef int         (*GetPluginIDFunc)();                        // Opsiyonel: Sayısal ID (1-255)
typedef const char* (*GetCategoryFunc)();                        // Opsiyonel: "haptic", "visual", "telemetry"
typedef void        (*StartFunc)(const char* phoneIp, int port); // Yeni arayüz: IP/port ile başlat
typedef void        (*StartFuncLegacy)();                        // Eski arayüz: parametresiz
typedef void        (*StopFunc)();                               // Zorunlu: Durdur

struct LoadedPlugin {
    std::string filename;
    HMODULE handle;
    GetInfoFunc getInfo;
    GetPluginIDFunc getPluginID;   // nullptr olabilir (opsiyonel)
    GetCategoryFunc getCategory;   // nullptr olabilir (opsiyonel)
    StartFunc start;               // Yeni arayüz (nullptr olabilir)
    StartFuncLegacy startLegacy;   // Eski arayüz (nullptr olabilir)
    StopFunc stop;
    bool isRunning;
    int assignedID;                // Gerçek veya otomatik atanmış ID
    std::string assignedCategory;  // Gerçek veya varsayılan kategori
    std::chrono::steady_clock::time_point lastHeartbeat;
};

class PluginManager {
private:
    std::vector<LoadedPlugin> plugins;
    std::thread addonListenerThread;
    std::thread watchdogThread;
    bool isListening = false;
    SOCKET addonSock = INVALID_SOCKET;
    std::mutex pluginMutex;
    int nextAutoID = 1; // GetPluginID olmayan DLL'ler için otomatik ID

    std::vector<std::string> GetSearchDirectories(const std::string& ekKlasorYolu) {
        std::vector<std::string> dirs;
        std::set<std::string> uniquePaths;

        char exePath[MAX_PATH] = { 0 };
        if (GetModuleFileNameA(NULL, exePath, MAX_PATH) > 0) {
            std::filesystem::path p(exePath);
            std::filesystem::path dir = p.parent_path();
            std::filesystem::path mainEkDir = dir / "DoYaDi_Ek";
            std::string mainStr = mainEkDir.string();
            try {
                if (std::filesystem::exists(mainEkDir)) {
                    mainStr = std::filesystem::canonical(mainEkDir).string();
                } else {
                    mainStr = std::filesystem::absolute(mainEkDir).string();
                }
            } catch (...) {
                mainStr = std::filesystem::absolute(mainEkDir).string();
            }
            dirs.push_back(mainEkDir.string());
            uniquePaths.insert(mainStr);
        }

        if (!ekKlasorYolu.empty()) {
            std::filesystem::path ekPath(ekKlasorYolu);
            std::string ekStr = ekPath.string();
            try {
                if (std::filesystem::exists(ekPath)) {
                    ekStr = std::filesystem::canonical(ekPath).string();
                } else {
                    ekStr = std::filesystem::absolute(ekPath).string();
                }
            } catch (...) {
                ekStr = std::filesystem::absolute(ekPath).string();
            }
            if (uniquePaths.find(ekStr) == uniquePaths.end()) {
                dirs.push_back(ekKlasorYolu);
                uniquePaths.insert(ekStr);
            }
        }
        return dirs;
    }

public:
    void Init(const std::string& ekKlasorYolu) {
        std::set<std::string> loadedFiles;
        auto searchDirs = GetSearchDirectories(ekKlasorYolu);

        for (const auto& d : searchDirs) {
            std::cout << "[PLUGIN] Tarama Yapilan Dizin: " << d << std::endl;
            if (!std::filesystem::exists(d)) {
                try { std::filesystem::create_directories(d); } catch (...) {}
            }
            if (std::filesystem::exists(d) && std::filesystem::is_directory(d)) {
                try {
                    for (const auto& entry : std::filesystem::directory_iterator(d)) {
                        std::string ext = entry.path().extension().string();
                        for (auto& c : ext) c = (char)tolower(c);
                        if (ext == ".dll") {
                            std::string fname = entry.path().filename().string();
                            if (loadedFiles.find(fname) == loadedFiles.end()) {
                                loadedFiles.insert(fname);
                                std::cout << "[PLUGIN] DLL Bulundu ve Yukleniyor: " << entry.path().string() << std::endl;
                                LoadSinglePlugin(entry.path().string());
                            }
                        }
                    }
                } catch (...) {}
            }
        }

        // 3. 8891 portu dinlemesini başlat
        StartAddonListener();

        // 4. Addon watchdog'u başlat (güvenlik freni)
        StartAddonWatchdog();
    }

    void LoadSinglePlugin(const std::string& path) {
        std::filesystem::path absPath = std::filesystem::absolute(path);
        std::string absPathStr = absPath.string();

        // LOAD_WITH_ALTERED_SEARCH_PATH: DLL'in kendi dizinini bağımlı DLL arama yoluna dahil eder
        HMODULE hMod = LoadLibraryExA(absPathStr.c_str(), NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
        if (!hMod) {
            DWORD err = GetLastError();
            std::cerr << "[PLUGIN HATA] DLL yuklenemedi: " << absPathStr 
                      << " (Hata Kodu: " << err << ")" << std::endl;
            return;
        }

        // Zorunlu fonksiyonlar
        GetInfoFunc info = (GetInfoFunc)GetProcAddress(hMod, "GetPluginInfo");
        StopFunc stop    = (StopFunc)GetProcAddress(hMod, "StopPlugin");

        // StartPlugin: önce yeni arayüzü (IP/port parametreli) dene, yoksa eski arayüzü al
        StartFunc start         = (StartFunc)GetProcAddress(hMod, "StartPlugin");
        StartFuncLegacy legacy  = nullptr;

        // Zorunlu fonksiyonlar eksikse uyumsuz kabul et ve kapat
        if (!info || !start || !stop) {
            FreeLibrary(hMod);
            std::cerr << "[PLUGIN HATA] Uyumsuz veya gecersiz DLL (GetPluginInfo/StartPlugin/StopPlugin eksik): " << absPathStr << std::endl;
            return;
        }

        // Opsiyonel fonksiyonlar
        GetPluginIDFunc id  = (GetPluginIDFunc)GetProcAddress(hMod, "GetPluginID");
        GetCategoryFunc cat = (GetCategoryFunc)GetProcAddress(hMod, "GetCategory");

        LoadedPlugin p;
        p.filename = absPathStr;
        p.handle = hMod;
        p.getInfo = info;
        p.getPluginID = id;     // nullptr olabilir
        p.getCategory = cat;    // nullptr olabilir
        p.stop = stop;
        p.isRunning = false;
        p.lastHeartbeat = std::chrono::steady_clock::now();

        // Yeni/eski arayüz ayrımı: GetPluginID varsa yeni arayüz, yoksa eski
        if (id) {
            p.start = start;
            p.startLegacy = nullptr;
            p.assignedID = id();
        } else {
            p.start = nullptr;
            p.startLegacy = (StartFuncLegacy)GetProcAddress(hMod, "StartPlugin");
            p.assignedID = nextAutoID++;
        }

        p.assignedCategory = cat ? std::string(cat()) : "general";

        plugins.push_back(p);
        std::cout << "[PLUGIN] Basariyla yuklendi: " << info()
                  << " (ID:" << p.assignedID
                  << ", Kategori:" << p.assignedCategory << ")" << std::endl;
    }

    // ── Addon Listener: 8891 UDP ────────────────────────────────────────────
    // Hem 3-byte DLC komutlarını (0xEE) hem de string mesajlarını (DOYADI_ADDON_LIST) dinler.
    void StartAddonListener() {
        isListening = true;
        addonListenerThread = std::thread([this]() {
            addonSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
            BOOL reuse = TRUE;
            setsockopt(addonSock, SOL_SOCKET, SO_REUSEADDR, (const char*)&reuse, sizeof(reuse));

            sockaddr_in serverAddr = { 0 };
            serverAddr.sin_family = AF_INET;
            serverAddr.sin_port = htons(8891);
            serverAddr.sin_addr.s_addr = INADDR_ANY;

            if (bind(addonSock, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
                std::cerr << "[HATA] Addon yonetim portu (8891) mesgul! Error: " << WSAGetLastError() << std::endl;
                closesocket(addonSock);
                return;
            }

            // Socket timeout: thread'i kilitlememek için
            DWORD timeout = 1000;
            setsockopt(addonSock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout, sizeof(timeout));

            std::cout << "[SISTEM] Addon Yonetim Portu (8891) aktif edildi." << std::endl;

            unsigned char buffer[512];
            sockaddr_in clientAddr;
            int clientAddrLen = sizeof(clientAddr);

            while (isListening) {
                int bytes = recvfrom(addonSock, (char*)buffer, 512, 0, 
                                     (sockaddr*)&clientAddr, &clientAddrLen);
                
                if (bytes <= 0) continue; // Timeout veya hata — devam et

                // ── 3-byte DLC Komut: [0xEE, PluginID, Durum] ──
                if (bytes == 3 && buffer[0] == 0xEE) {
                    int pluginID = buffer[1];
                    bool isActive = (buffer[2] == 0x01);

                    // Gönderen telefonun IP adresini al
                    char phoneIp[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, &clientAddr.sin_addr, phoneIp, INET_ADDRSTRLEN);

                    // DLL başlatma süresinin dinleme döngüsünü bloklamasını önle
                    std::string ipStr(phoneIp);
                    std::thread([this, pluginID, isActive, ipStr]() {
                        try {
                            ProcessCommand(pluginID, isActive, ipStr.c_str());
                        } catch (...) {
                            std::cerr << "[HATA] UDP ProcessCommand exception!" << std::endl;
                        }
                    }).detach();
                }
                // ── String Mesaj: DOYADI_ADDON_LIST ──
                else if (bytes >= 17) {
                    std::string msg((char*)buffer, bytes);
                    if (msg.find("DOYADI_ADDON_LIST") != std::string::npos) {
                        std::cout << "[ADDON] Telefondan DOYADI_ADDON_LIST talebi alindi." << std::endl;
                        std::string json = GetAddonListJson();
                        std::cout << "[ADDON] Gonderilen Yanit: " << json << std::endl;
                        sendto(addonSock, json.c_str(), (int)json.length(), 0,
                               (sockaddr*)&clientAddr, clientAddrLen);
                    }
                }
            }
            closesocket(addonSock);
        });
        addonListenerThread.detach();
    }

    // ── Komut İşleme: ID bazlı (Hash mantığı tamamen kaldırıldı) ────────────
    void ProcessCommand(int pluginID, bool isActive, const char* phoneIp) {
        std::lock_guard<std::mutex> lock(pluginMutex);
        for (auto& p : plugins) {
            if (p.assignedID == pluginID) {
                if (isActive && !p.isRunning) {
                    // Eklentiyi başlat
                    if (p.start) {
                        // Yeni arayüz: telefon IP ve portunu ver
                        p.start(phoneIp, 8890);
                    } else if (p.startLegacy) {
                        // Eski arayüz: parametresiz çağır
                        p.startLegacy();
                    }
                    p.isRunning = true;
                    p.lastHeartbeat = std::chrono::steady_clock::now();
                    std::cout << "[PLUGIN] Baslatildi: " << p.getInfo()
                              << " -> " << phoneIp << ":8890" << std::endl;
                }
                else if (isActive && p.isRunning) {
                    // Heartbeat güncelle (güvenlik freni beslemesi)
                    p.lastHeartbeat = std::chrono::steady_clock::now();
                }
                else if (!isActive && p.isRunning) {
                    // Eklentiyi durdur
                    p.stop();
                    p.isRunning = false;
                    std::cout << "[PLUGIN] Durduruldu: " << p.getInfo() << std::endl;
                }
                break;
            }
        }
    }

    // ── Addon Watchdog: Güvenlik Freni ───────────────────────────────────────
    // Telefon bağlantısı tamamen koparsa (60 saniye komut/kalp atışı gelmezse)
    // eklentiyi otomatik durdurur. Eklenti panelinden kapatıldığında (0x00) ise ANINDA sonlanır.
    void StartAddonWatchdog() {
        watchdogThread = std::thread([this]() {
            while (isListening) {
                Sleep(1000); // Her saniye kontrol et

                std::lock_guard<std::mutex> lock(pluginMutex);
                auto now = std::chrono::steady_clock::now();

                for (auto& p : plugins) {
                    if (p.isRunning) {
                        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                            now - p.lastHeartbeat).count();
                        
                        if (ms > 60000) { // 60 saniye tam kopma durumunda emniyet için durdur
                            p.stop();
                            p.isRunning = false;
                            std::cerr << "[ADDON WATCHDOG] " << p.getInfo() 
                                      << " emniyet icin otomatik durduruldu (baglanti zamanasimi: " 
                                      << ms << "ms)" << std::endl;
                        }
                    }
                }
            }
        });
        watchdogThread.detach();
    }

    void RescanPluginsInternal() {
        std::set<std::string> loadedFiles;
        for (const auto& p : plugins) {
            std::filesystem::path path(p.filename);
            loadedFiles.insert(path.filename().string());
        }

        auto searchDirs = GetSearchDirectories(".\\DoYaDi_Ek");
        for (const auto& d : searchDirs) {
            if (std::filesystem::exists(d) && std::filesystem::is_directory(d)) {
                try {
                    for (const auto& entry : std::filesystem::directory_iterator(d)) {
                        std::string ext = entry.path().extension().string();
                        for (auto& c : ext) c = (char)tolower(c);
                        if (ext == ".dll") {
                            std::string fname = entry.path().filename().string();
                            if (loadedFiles.find(fname) == loadedFiles.end()) {
                                loadedFiles.insert(fname);
                                std::cout << "[PLUGIN] Canli Akista Yeni DLL Bulundu: " << entry.path().string() << std::endl;
                                LoadSinglePlugin(entry.path().string());
                            }
                        }
                    }
                } catch (...) {}
            }
        }
    }

    // ── JSON Addon Listesi ──────────────────────────────────────────────────
    // Telefonun "Ek İçerikleri Getir" butonuna yanıt olarak gönderilir.
    std::string GetAddonListJson() {
        std::lock_guard<std::mutex> lock(pluginMutex);
        RescanPluginsInternal();
        std::string json = "[";
        for (size_t i = 0; i < plugins.size(); i++) {
            if (i > 0) json += ",";
            
            std::string name = plugins[i].getInfo();
            std::string category = plugins[i].assignedCategory;
            int id = plugins[i].assignedID;

            // JSON özel karakterlerini escape et (basit)
            for (auto& c : name) { if (c == '"') c = '\''; }
            for (auto& c : category) { if (c == '"') c = '\''; }

            json += "{";
            json += "\"id\":\"plugin_" + std::to_string(id) + "\",";
            json += "\"numericId\":" + std::to_string(id) + ",";
            json += "\"name\":\"" + name + "\",";
            json += "\"category\":\"" + category + "\"";
            json += "}";
        }
        json += "]";
        return json;
    }

    // ── Bluetooth Yönlendirme Desteği ───────────────────────────────────────
    // server.cpp'deki BluetoothListener bu fonksiyonları çağırır.

    /// BT stream'inden gelen DOYADI_ADDON_LIST talebine JSON yanıt üret.
    /// Dönen buffer: [0xAA, lenHigh, lenLow, ...JSON_UTF8...]
    std::vector<unsigned char> GetAddonListForBluetooth() {
        std::string json = GetAddonListJson();
        int len = (int)json.length();

        std::vector<unsigned char> response;
        response.push_back(0xAA);                      // İmza
        response.push_back((len >> 8) & 0xFF);          // Uzunluk High
        response.push_back(len & 0xFF);                 // Uzunluk Low
        response.insert(response.end(), json.begin(), json.end()); // JSON data
        return response;
    }

    void Shutdown() {
        isListening = false;
        closesocket(addonSock);

        std::lock_guard<std::mutex> lock(pluginMutex);
        for (auto& p : plugins) {
            if (p.isRunning) {
                p.stop();
                p.isRunning = false;
            }
            FreeLibrary(p.handle);
        }
        plugins.clear();
    }
};