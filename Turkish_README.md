<h1>DoYaDi: Gelişmiş Bilgisayar Uzaktan Kontrolcüsü ve Sanal Yarış Direksiyonu</h1>

DoYaDi, mobil cihazınızı Wi-Fi, kablo veya Bluetooth aracılığıyla yüksek hassasiyetli bir sanal yarış direksiyonuna, gamepad'e ve dokunmatik fareye (touchpad) dönüştüren hibrit bir kontrol çözümüdür. Standart sanal direksiyon uygulamalarının aksine, düşük gecikmeli veri iletimi ve dinamik hassasiyet algoritmalarıyla profesyonel bir sürüş deneyimi sunmayı hedefler.

<h2>🚀 Temel Özellikler</h2>

    16-Bayt "Özgürlük" Mimarisi: Düşük ağ yükü ve yüksek hız için veri iletimini optimize eden özel veri paketi (payload) yapısı.

    60 FPS Oyun Döngüsü: Gecikmesiz bir deneyim için Flutter tarafında saniyede 60 kez sürekli veri pompalama (UDP/BT).

    Dinamik Değişken Oranlı Direksiyon: Cihazın yunuslama (pitch) açısına bağlı olarak direksiyon hassasiyetini anında ayarlayan matematiksel bir model.

      İnce Ayar Bölgesi (50°-70°): Milimetrik manevralar için düşük hassasiyet.

      Agresif Mod (110°-130°): Hızlı dönüşler için yüksek tepkisellik.

    Akıllı Touchpad ve Fare Kontrolü: Windows SendInput API'si ile güçlendirilmiş, 1, 2 ve 3 parmak dokunuşlarını (Sol, Sağ ve Orta Tıklama) algılayan touchpad entegrasyonu.

    Klavye Makroları ve Anti-Ghosting: Doğrudan cihaz üzerinden herhangi bir PC tuşunu (F1-F12, Shift, Ctrl vb.) tetikleyebilme ve aynı anda 4 tuşa kadar basım desteği.

    Güvenli Geri Tuşu Mantığı: Yanlışlıkla dokunmaları ve istenmeyen sayfa geçişlerini önlemek için isExiting durum kontrolü ve IgnorePointer izolasyonu uygular.

<h2>🛠 Teknik Mimari</h2>

Proje, bir mobil istemci (Flutter) ve bir Windows sunucusundan (C++) oluşmaktadır.

  <h3>📱 Mobil Uygulama (Flutter)</h3>

    Sensör Yönetimi: İvmeölçer ve jiroskop verilerinin atan2 trigonometrik fonksiyonları kullanılarak işlenmesi.

    Ağ Katmanı: Wi-Fi ve kablo üzerinden UDP, Bluetooth üzerinden RFCOMM (SPP) protokolleri.

    Arayüz/Kullanıcı Deneyimi (UI/UX): CustomPainter ve gelişmiş GestureDetector mimarilerinden yararlanan özelleştirilebilir buton dizilimleri (Mod 5).

<h3>🖥 PC Sunucusu (C++)</h3>

    Donanım Emülasyonu: ViGEmBus kütüphanesi kullanılarak sanal bir Xbox 360 kontrolcüsü oluşturulması.

    Windows API Entegrasyonu: Fare ve klavye olayları için düşük seviyeli SendInput fonksiyonları.

    Çoklu İş Parçacığı (Multithreading): UDP Keşfi (Discovery), Veri Dinleyici (Data Listener) ve Bluetooth servislerinin eşzamanlı olarak yürütülmesi.

<h2>📊 Payload (Veri Yükü) Yapısı</h2>

    Sistem, son derece verimli 16-Baytlık özel bir protokol kullanır:

    Bayt 0-4: Temel Araç Kontrolleri (Direksiyon, Gaz, Fren, Butonlar)

    Bayt 5-8: Analog Çubuklar (X, Y eksenleri)

    Bayt 9-10: Fare Delta Hareketleri (X, Y)

    Bayt 11: Fare Tıklama Durumları (0: Yok, 1: Sol, 2: Sağ, 3: Orta)

    Bayt 12-15: Aktif Sanal Tuş Kodları (Anti-Ghosting Yuvaları)

<i>'Eğer kullanıcı direksiyon 5'e joystick, dokunmatik fare veya klavye tuşları eklemediyse gönderim boyutu 5 bayt ile sınırlı kalır.'</i>

<h2>🤖 Geliştirme Süreci ve Yapay Zeka Hakkında</h2>

eliştirme süreci boyunca Gemini, Claude / AntiGravity gibi büyük dil modelleri (LLM'ler) mimari beyin fırtınası, matematiksel modelleme ve hata ayıklama (debugging) için kullanılmıştır.

Yapay zeka "yazan el" olarak hizmet verirken; temel vizyon, dinamik hassasiyetin arkasındaki mantık ve altta yatan tüm mühendislik kararları tamamen geliştiriciye aittir.

<h2>🔧 Kurulum</h2>

<h3>PC Sunucusu:</h3>
        
        * Windows bilgisayarınıza ViGEmBus sürücüsünü kurun.
        * C++ projesini Visual Studio kullanarak derleyin ve yürütülebilir dosyayı (executable) çalıştırın.
        Uyarı:
            - Sunucuyu Bluetooth'u açmadan önce başlatırsanız, Bluetooth'u açtıktan sonra sunucuyu yeniden başlatmanız gerekir.
            - Eğer internet ile kullanmak isterseniz, yalnızca Özel Ağlarda (private networks) çalışır.
        
       
  Sunucu kurulum dosyası setup.exe'yi indirmek için -> <a href="https://github.com/Navilastro/DoYaDi/releases/tag/server_setup">İndir</a>. Arka planda güvenlik duvarı izinlerini otomatik halleder.

<h4>.iss özel bölümü:</h4>
 
    [Run]

    ; Firewall kurallarini sessizce ekler. Sadece Özel Aglarda (profile=private) ve sadece DoYaDi_Server.exe için izin verir.
    Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DoYaDi UDP Discovery"" dir=in action=allow protocol=UDP localport=8889 profile=private program=""{app}{#MyAppExeName}"""; Flags: runhidden
    Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DoYaDi UDP Data"" dir=in action=allow protocol=UDP localport=8888 profile=private program=""{app}{#MyAppExeName}"""; Flags: runhidden

    ; Kurulum biter bitmez programi calistirir.
    Filename: "{app}{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent


    [UninstallRun]
   
    ; Program bilgisayardan kaldirilirken iz birakmamak icin Firewall kurallarini temizler.
    Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DoYaDi UDP Discovery"""; Flags: runhidden
    Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DoYaDi UDP Data"""; Flags: runhidden

<h2>Mobil Uygulama:</h2>

    Bilgisayarınızda/cihazınızda Flutter SDK kurulu ise, "flutter build apk --release" komutu ile uygulamayı derleyebilirsiniz.

    İki cihazın da aynı ağa bağlı olduğundan emin olun ve "Bağlan" (Connect) butonuna tıklayın.

    Bluetooth bağlantısı için iki cihazın Bluetooth üzerinden birbiriyle önceden eşleşmiş olması gerekir.

Ayrıca doğrudan <a href="https://github.com/Navilastro/DoYaDi/releases/tag/DoYaDi_app">indirebilirsiniz</a>.

<h2>Neden Yaptım?</h2>

    Daha öncesinde yarış oyunları oynarken daha önceden yapılmış uygulamaları kullanırdım. Ancak gerek özelleştirme seçeneklerinin kısıtlı olması gerek bilgisayara birden fazla şey indirmenin gerekmesi, gereskse de bazen wifi bağlantısını bozması gibi sebeplerden dolayı bu projeyi geliştirme kararı aldım. 
    Türevlerinde olmayan; özelleştirme seçenekleri ekledim, kontrolcü ayarlarını telefona taşıyarak gecikmeyi azalttım ve daha kapsamlı hale getirdim.

👨‍💻 Geliştirici
  >Efe Pehlivan
