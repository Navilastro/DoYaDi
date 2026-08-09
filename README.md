<h1>DoYaDi: Ultimate PC Remote Controller & Virtual Racing Wheel</h1>

<a href ="https://github.com/Navilastro/DoYaDi/blob/main/Turkish_README.md">🇹🇷 Türkçe dokümantasyon için tıklayın (Click for Turkish version)</a>

DoYaDi is a hybrid control solution that transforms your mobile device into a high-precision virtual racing wheel, gamepad, and touchpad via Wi-Fi, with cable or Bluetooth. Unlike standard virtual steering apps, it aims to deliver a professional driving experience with low-latency data transmission and dynamic sensitivity algorithms.

<h2>🚀 Key Features</h2>

*   **16/17-Byte "Freedom" Architecture:** Custom payload structure optimizing data transmission for low network overhead and high speed, dynamically adapting size based on active layout components.
*   **60 FPS Game Loop:** Continuous data pumping (UDP/BT) at 60 times per second on the Flutter side for a zero-lag experience.
*   **Dynamic Variable Ratio Steering:** A mathematical model that instantly adjusts steering sensitivity based on the device's pitch angle.
    *   Fine-Tuning Zone (50°-70°): Low sensitivity for millimeter-precise maneuvers.
    *   Aggressive Mode (110°-130°): High responsiveness for quick turns.
*   **Analog Clutch & Handbrake (Raw Data):** Mapped to the Right Analog Stick (Z-Axis/Rotation) for zero-smoothing, delivering 1:1 direct analog inputs without the need for external drivers like vJoy.
*   **Smart Touchpad & Mouse Control:** Touchpad integration that detects 1, 2, and 3-finger taps (Left, Right, and Middle Click) powered by the Windows SendInput API.
*   **Keyboard Macros & Anti-Ghosting:** Trigger any PC key (F1-F12, Shift, Ctrl, etc.) directly from the device, supporting up to 4 simultaneous keystrokes.
*   **Safe Back Button Logic:** Implements isExiting state control and IgnorePointer isolation to prevent accidental touches and unintended page navigation.
*   **Extensible Addon (DLC) System:** Support for external DLL plugins managed by a dedicated C++ PluginManager, allowing game-specific extensions (e.g., ETS2/ATS telemetry) to interact with the mobile app through dedicated channels.
*   **Real-time Telemetry & Haptic Feedback:** Dedicated telemetry listener (UDP 8890 / BT) streams live game data to the mobile device for visual and haptic (vibration) feedback.
*   **Thread-Safe Asynchronous Architecture:** Highly stable, non-blocking network streams ensuring zero interference between high-frequency driving inputs and addon communications.
*   It allows up to four controllers!

<h2>🛠 Technical Architecture</h2>

The project consists of a mobile client (Flutter) and a Windows server (C++).

<h3>📱 Mobile App (Flutter)</h3>

*   **Sensor Management:** Processing accelerometer and gyroscope data using atan2 trigonometric functions.
*   **Network Layer:** UDP over Wi-Fi, cable and RFCOMM (SPP) protocols over Bluetooth.
*   **UI/UX:** Customizable button layouts (Mode 5) utilizing CustomPainter and advanced GestureDetector architectures.

<h3>🖥 PC Server (C++)</h3>

*   **Hardware Emulation:** Creating a virtual Xbox 360 controller using the ViGEmBus library. **(Statically linked via `.lib` for a standalone, clean executable without external `.dll` dependencies).**
*   **Windows API Integration:** Low-level SendInput functions for mouse and keyboard events.
*   **Plugin Management:** Asynchronous DLL loading and command processing to handle external add-ons without blocking the main driving loop.
*   **Multithreading:** Simultaneous execution of UDP Discovery, Data Listener, and Bluetooth services.

<h2>📊 Payload Structure</h2>

The system utilizes a highly efficient custom protocol (up to 17 Bytes):

*   **Byte 0-4:** Core Vehicle Controls (Steering, Throttle, Brake, Buttons)
*   **Byte 5-8:** Analog Sticks (Left/Right X, Y axes) **enabling precise clutch and handbrake mapping.**
*   **Byte 9-10:** Mouse Delta Movements (X, Y)
*   **Byte 11:** Mouse Click States (0: None, 1: Left, 2: Right, 3: Middle)
*   **Byte 12-15:** Active Virtual Key Codes (Anti-Ghosting Slots)

<i>'If the user hasn't added a joystick, touchpad, or keyboard keys to steering wheel 5, the data transmission size remains strictly limited to 5 bytes.'</i>

<h2>🤖 About the Development Process & AI</h2>

This project is a testament to modern Pair-Programming. Throughout the development process, large language models (LLMs) like Gemini, Claude / AntiGravity were utilized for architectural brainstorming, mathematical modeling, and debugging.

While AI served as the "typing hand," the core vision, the logic behind dynamic sensitivity, and all underlying engineering decisions belong entirely to the developer. This collaboration showcases the power of utilizing modern development tools to build complex, low-latency systems.

<h2>🔧 Installation</h2>

<h3>PC Server:</h3>

*   Install the ViGEmBus driver on your Windows machine.
*   Compile the C++ project using Visual Studio and run the executable.
*   **Pro-Tip for Simulators (e.g., Assetto Corsa):** For raw data transmission without interference, ensure you clear "ghost" controllers from the Windows Device Manager (JoyID registry) and select **"Disable Steam Input"** in your game's Steam controller settings.
*   **Warning:**
    *   If you start the server before opening up the bluetooth, you need to restart the server after opening up.
    *   If you want to use it with the internet, it only works on private networks.

For download server setup.exe -> <a href="https://github.com/Navilastro/DoYaDi/releases/tag/server_setup">Download</a> It handles firewall permissions in the background.

<h4>.iss special part:</h4>

    [Languages]
      Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
      Name: "english"; MessagesFile: "compiler:Default.isl"

    [Tasks]
      Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

      [Files]
      Source: "..\DoYaDi_Server\x64\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

      [Icons]
      Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
      Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

      [INI]
      Filename: "{app}\config.ini"; Section: "Settings"; Key: "Language"; String: "{language}"

      [Dirs]
      Name: "{app}\DoYaDi_Ek"

      [Run]

      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DoYaDi UDP Discovery"" dir=in action=allow protocol=UDP localport=8889 profile=private program=""{app}\{#MyAppExeName}"""; Flags: runhidden
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DoYaDi UDP Data"" dir=in action=allow protocol=UDP localport=8888 profile=private program=""{app}\{#MyAppExeName}"""; Flags: runhidden
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DoYaDi UDP Telemetry"" dir=in action=allow protocol=UDP localport=8890 profile=private program=""{app}\{#MyAppExeName}"""; Flags: runhidden
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DoYaDi UDP Addon"" dir=in action=allow protocol=UDP localport=8891 profile=private program=""{app}\{#MyAppExeName}"""; Flags: runhidden

      Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent


      [UninstallRun]
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DoYaDi UDP Discovery"""; Flags: runhidden
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DoYaDi UDP Data"""; Flags: runhidden
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DoYaDi UDP Telemetry"""; Flags: runhidden
      Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DoYaDi UDP Addon"""; Flags: runhidden
        
<h3>Mobile App:</h3>

        With the Flutter SDK installed on your machine/device, you can build with "flutter build apk --release".

        Ensure both devices are on the same network and click the "Connect" button.

         For bluetooth connection, two devices must know each other's bluetooth.

  Also you can direcly <a href = "https://github.com/Navilastro/DoYaDi/releases/tag/DoYaDi_app">download</a>.

  <h2>Why I made this?:</h2>
    In the past, I used to rely on existing applications while playing racing games. However, I decided to develop this project due to several recurring issues with those apps: limited customization options, the hassle of having to download multiple dependencies to the computer, and occasional disruptions to the Wi-Fi connection.

  I introduced customization features that are missing in alternative apps. By moving the controller configurations directly to the phone, I significantly reduced latency and made the overall experience much more comprehensive.

👨‍💻 Developer
  >Efe Pehlivan


<p align="center">
  <sub>Copyright (c) 2026. Tüm hakları saklıdır. İzinsiz kopyalanamaz ve kullanılamaz.</sub>
</p>
