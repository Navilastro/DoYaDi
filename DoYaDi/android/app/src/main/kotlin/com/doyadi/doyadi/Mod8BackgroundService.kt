package com.doyadi.doyadi

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sign
import kotlin.math.sqrt

class Mod8BackgroundService : Service(), SensorEventListener {

    companion object {
        private const val CHANNEL_ID = "doyadi_mod8_bg_channel"
        private const val NOTIF_ID = 1008

        const val ACTION_START_ARMED = "com.doyadi.doyadi.START_ARMED"
        const val ACTION_UPDATE_CONFIG = "com.doyadi.doyadi.UPDATE_CONFIG"
        const val ACTION_ENTER_BACKGROUND = "com.doyadi.doyadi.ENTER_BACKGROUND"
        const val ACTION_EXIT_BACKGROUND = "com.doyadi.doyadi.EXIT_BACKGROUND"
        const val ACTION_STOP = "com.doyadi.doyadi.STOP_MOD8_BG"
        const val ACTION_RECALIBRATE = "com.doyadi.doyadi.MOD8_RECALIBRATE"
        const val ACTION_GEAR_DOWN = "com.doyadi.doyadi.MOD8_GEAR_DOWN"
        const val ACTION_GEAR_UP = "com.doyadi.doyadi.MOD8_GEAR_UP"

        private const val TAG = "DoYaDiMod8Bg"

        /** Çalışan servis örneği (arka plana geçişte intent yerine doğrudan çağrı için). */
        @Volatile
        var instance: Mod8BackgroundService? = null

        @Volatile
        var isArmedForMod8: Boolean = false

        @Volatile
        var isInBackgroundMode: Boolean = false

        @Volatile
        var targetIp: String = ""

        @Volatile
        var steerSens: Double = 1.0

        @Volatile
        var gasBrakeSens: Double = 1.0

        @Volatile
        var steeringAngleDeg: Double = 180.0

        @Volatile
        var steeringAxis: Int = 0 // 0 = Roll, 1 = Yaw

        @Volatile
        var showGearButtons: Boolean = true

        @Volatile
        var overlayStyle: Int = 0 // 0: Kapsül Kart, 1: Dikey 3 Yuvarlak

        @Volatile
        var basePitch: Double = 45.0

        @Volatile
        var baseRoll: Double = 0.0

        @Volatile
        var hasCustomBase: Boolean = false

        @Volatile
        var cruiseLocked: Boolean = false

        @Volatile
        var cruiseGasValue: Double = 0.0

        @Volatile
        var overlayBgColor: Int = Color.parseColor("#EB0A0A18")

        @Volatile
        var overlayBorderColor: Int = Color.parseColor("#CC40E0D0")

        @Volatile
        var overlaySteerColor: Int = Color.parseColor("#40E0D0")

        @Volatile
        var overlayGasColor: Int = Color.parseColor("#00E676")

        @Volatile
        var overlayBrakeColor: Int = Color.parseColor("#FF2A6D")

        @Volatile
        var overlayGearBtnColor: Int = Color.parseColor("#40E0D0")

        @Volatile
        var lang: String = "tr"

        private fun isEn(): Boolean = lang.equals("en", ignoreCase = true) || lang.startsWith("en", ignoreCase = true)

        private fun withAlphaInt(color: Int, alpha: Int): Int {
            return (color and 0x00FFFFFF) or ((alpha.coerceIn(0, 255)) shl 24)
        }

        private fun contrastTextInt(bgColor: Int): Int {
            val r = Color.red(bgColor) / 255.0
            val g = Color.green(bgColor) / 255.0
            val b = Color.blue(bgColor) / 255.0
            val lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return if (lum > 0.55) Color.BLACK else Color.WHITE
        }

        var onRecalibrateCallback: ((Double, Double) -> Unit)? = null
        var onBluetoothPacketCallback: ((ByteArray) -> Unit)? = null
        var onOverlayClosedByUserCallback: (() -> Unit)? = null
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    private var sensorManager: SensorManager? = null
    private var accelSensor: Sensor? = null
    private var gyroSensor: Sensor? = null
    private var sensorsRegistered = false

    private var lastRawPitch: Double = 45.0
    private var lastRawRoll: Double = 0.0
    private var accumYaw: Double = 0.0
    private var lastGyroTimeNs: Long = 0L

    private var currentSteering: Double = 0.0
    private var currentGas: Double = 0.0
    private var currentBrake: Double = 0.0

    private var gearDownPressed: Boolean = false
    private var gearUpPressed: Boolean = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private val udpExecutor = Executors.newSingleThreadExecutor()
    private var udpSocket: DatagramSocket? = null
    private var cachedInetAddress: InetAddress? = null
    private var cachedIpString: String = ""

    private var windowManager: WindowManager? = null
    private var bubbleRootView: View? = null
    private var bubbleLayoutParams: WindowManager.LayoutParams? = null
    private var steeringBarView: SteeringBarView? = null
    private var brakeTextView: TextView? = null
    private var steerTextView: TextView? = null
    private var gasTextView: TextView? = null
    private var gearRowView: LinearLayout? = null
    private var currentActiveOverlayStyle: Int = 0
    private var currentActiveOverlayLang: String = "tr"
    private var lastDisplayedSteerPct: Int = Int.MIN_VALUE
    private var lastDisplayedGasPct: Int = Int.MIN_VALUE
    private var lastDisplayedBrakePct: Int = Int.MIN_VALUE

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (!isArmedForMod8 || !isInBackgroundMode) return
            updateBubbleUi()
            sendCurrentPacket()
            mainHandler.postDelayed(this, 16L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        acquireLocks()
    }

    private var foregroundStarted = false

    private fun ensureForeground() {
        try {
            createNotificationChannel()
            val notification = buildNotification()
            if (!foregroundStarted) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIF_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(NOTIF_ID, notification)
                }
                foregroundStarted = true
            } else {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                nm?.notify(NOTIF_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground başarısız: $e")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START_ARMED

        if (action == ACTION_STOP) {
            onOverlayClosedByUserCallback?.invoke()
            stopEverything()
            stopSelf()
            return START_NOT_STICKY
        }

        // Android 8+ kuralı: startForegroundService ile başlatılan servis 5 sn içinde
        // startForeground çağırmalıdır. Sadece ilk seferde gerçek çağrı yapılır.
        ensureForeground()
        acquireLocks()

        when (action) {
            ACTION_START_ARMED, ACTION_UPDATE_CONFIG -> applyConfigUpdate()
            ACTION_ENTER_BACKGROUND -> requestEnterBackground()
            ACTION_EXIT_BACKGROUND -> requestExitBackground()
            ACTION_RECALIBRATE -> recalibrateNow()
            ACTION_GEAR_DOWN -> pulseGear(isUp = false)
            ACTION_GEAR_UP -> pulseGear(isUp = true)
        }

        return START_STICKY
    }

    /** Ayar değişikliklerini (intent göndermeden) canlı uygular. */
    fun applyConfigUpdate() {
        mainHandler.post {
            gearRowView?.visibility = if (showGearButtons) View.VISIBLE else View.GONE
            if (isInBackgroundMode && bubbleRootView != null) {
                if (currentActiveOverlayStyle != overlayStyle || currentActiveOverlayLang != lang) {
                    hideBubbleOverlay()
                    showBubbleOverlay()
                } else {
                    updateBubbleUi()
                }
            }
        }
    }

    /** Uygulama arka plana atıldığında MainActivity tarafından doğrudan çağrılır. */
    fun requestEnterBackground() {
        mainHandler.post {
            if (isArmedForMod8) {
                enterBackgroundModeInternal()
            } else {
                Log.w(TAG, "Arka plan isteği yok sayıldı: Mod 8 silahlı değil")
            }
        }
    }

    /** Uygulama ön plana döndüğünde doğrudan çağrılır. */
    fun requestExitBackground() {
        mainHandler.post { exitBackgroundModeInternal() }
    }

    private fun pulseGear(isUp: Boolean) {
        if (isUp) gearUpPressed = true else gearDownPressed = true
        sendCurrentPacket()
        mainHandler.postDelayed({
            if (isUp) gearUpPressed = false else gearDownPressed = false
            sendCurrentPacket()
        }, 140L)
    }

    private fun enterBackgroundModeInternal() {
        if (!isArmedForMod8) return
        if (isInBackgroundMode && bubbleRootView != null) return
        isInBackgroundMode = true
        registerSensorsIfNeeded()
        showBubbleOverlay()
        // Bildirimi güncelle (baloncuk izni yoksa kullanıcıya bildirim butonları kalır)
        ensureForeground()
        mainHandler.removeCallbacks(tickRunnable)
        mainHandler.post(tickRunnable)
        Log.d(TAG, "Arka plan sürüşü başladı (baloncuk=${bubbleRootView != null})")
    }

    private fun exitBackgroundModeInternal() {
        if (!isInBackgroundMode && bubbleRootView == null) return
        isInBackgroundMode = false
        gearDownPressed = false
        gearUpPressed = false
        mainHandler.removeCallbacks(tickRunnable)
        unregisterSensors()
        hideBubbleOverlay()
    }

    private fun stopEverything() {
        isArmedForMod8 = false
        exitBackgroundModeInternal()
        releaseLocks()
        udpExecutor.execute {
            try {
                udpSocket?.close()
            } catch (_: Exception) {
            }
            udpSocket = null
        }
    }

    private fun registerSensorsIfNeeded() {
        if (sensorsRegistered) return
        try {
            accelSensor?.let {
                sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
            gyroSensor?.let {
                sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
            lastGyroTimeNs = 0L
            sensorsRegistered = true
        } catch (_: Exception) {
        }
    }

    private fun unregisterSensors() {
        if (!sensorsRegistered) return
        try {
            sensorManager?.unregisterListener(this)
        } catch (_: Exception) {
        }
        sensorsRegistered = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || !isArmedForMod8 || !isInBackgroundMode) return

        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            val ex = event.values[0].toDouble()
            val ey = event.values[1].toDouble()
            val ez = event.values[2].toDouble()

            val yzMag = sqrt(ey * ey + ez * ez)
            val rawRoll = atan2(-ex, max(0.1, yzMag)) * (180.0 / Math.PI)
            val rawPitchPort = atan2(ez, ey) * (180.0 / Math.PI)

            lastRawRoll = rawRoll
            lastRawPitch = rawPitchPort

            if (!hasCustomBase) {
                basePitch = rawPitchPort
                baseRoll = rawRoll
                hasCustomBase = true
            }

            val deltaPitch = rawPitchPort - basePitch
            val deltaRoll = rawRoll - baseRoll

            if (steeringAxis == 0) {
                val maxRoll = (steeringAngleDeg / 4.0).coerceIn(15.0, 65.0)
                val rollDeadzone = 2.0
                currentSteering = if (abs(deltaRoll) <= rollDeadzone) {
                    0.0
                } else {
                    val effRoll = (abs(deltaRoll) - rollDeadzone) * sign(deltaRoll)
                    ((effRoll / maxRoll) * steerSens).coerceIn(-1.0, 1.0)
                }
            }

            val pitchDeadzone = 4.0
            val fullPedalRangeDeg = 24.0
            var rawGas = 0.0
            var rawBrake = 0.0
            if (deltaPitch > pitchDeadzone) {
                rawGas = (((deltaPitch - pitchDeadzone) / fullPedalRangeDeg) * gasBrakeSens)
                    .coerceIn(0.0, 1.0)
            } else if (deltaPitch < -pitchDeadzone) {
                rawBrake = (((-deltaPitch - pitchDeadzone) / fullPedalRangeDeg) * gasBrakeSens)
                    .coerceIn(0.0, 1.0)
            }

            if (cruiseLocked) {
                if (rawBrake > 0.18) {
                    cruiseLocked = false
                    currentGas = 0.0
                    currentBrake = rawBrake
                } else {
                    currentGas = max(cruiseGasValue, rawGas)
                    currentBrake = 0.0
                }
            } else {
                currentGas = rawGas
                currentBrake = rawBrake
            }
        } else if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            if (steeringAxis == 1) {
                val nowNs = event.timestamp
                if (lastGyroTimeNs != 0L) {
                    val dt = (nowNs - lastGyroTimeNs) / 1_000_000_000.0
                    if (dt > 0.0 && dt < 0.5) {
                        val ey = event.values[1].toDouble()
                        val ez = event.values[2].toDouble()
                        val rawYawRate = -ez + ey * 0.5
                        if (abs(rawYawRate) >= 0.025) {
                            val maxYaw = (steeringAngleDeg / 4.0).coerceIn(15.0, 65.0)
                            accumYaw = (accumYaw + rawYawRate * (180.0 / Math.PI) * dt)
                                .coerceIn(-maxYaw * 1.5, maxYaw * 1.5)
                            currentSteering = ((accumYaw / maxYaw) * steerSens).coerceIn(-1.0, 1.0)
                        }
                    }
                }
                lastGyroTimeNs = nowNs
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun recalibrateNow() {
        basePitch = lastRawPitch
        baseRoll = lastRawRoll
        accumYaw = 0.0
        hasCustomBase = true
        currentSteering = 0.0
        currentGas = 0.0
        currentBrake = 0.0
        updateBubbleUi()
        onRecalibrateCallback?.invoke(basePitch, baseRoll)
    }

    private fun sendCurrentPacket() {
        val steerByte = (((currentSteering + 1.0) / 2.0) * 255.0).toInt().coerceIn(0, 255)
        val gasByte = (currentGas * 255.0).toInt().coerceIn(0, 255)
        val brakeByte = (currentBrake * 255.0).toInt().coerceIn(0, 255)

        var buttons = 0
        if (gearDownPressed) buttons = buttons or 0x0100 // LB
        if (gearUpPressed) buttons = buttons or 0x0200   // RB

        val buttonsHigh = (buttons shr 8) and 0xFF
        val buttonsLow = buttons and 0xFF

        val packetBytes = byteArrayOf(
            steerByte.toByte(),
            gasByte.toByte(),
            brakeByte.toByte(),
            buttonsHigh.toByte(),
            buttonsLow.toByte(),
            128.toByte(),
            128.toByte(),
            128.toByte(),
            128.toByte(),
            128.toByte(),
            128.toByte(),
            0,
            0,
            0,
            0,
            0,
            221.toByte()
        )

        // Wi-Fi / USB UDP doğrudan gönderim; yalnızca ip boşsa (BT modu) MethodChannel köprüsünü kullan
        val ip = targetIp.trim()
        if (ip.isEmpty()) {
            onBluetoothPacketCallback?.invoke(packetBytes)
        } else {
            udpExecutor.execute {
                try {
                    if (udpSocket == null || udpSocket?.isClosed == true) {
                        udpSocket = DatagramSocket()
                    }
                    if (cachedInetAddress == null || cachedIpString != ip) {
                        cachedInetAddress = InetAddress.getByName(ip)
                        cachedIpString = ip
                    }
                    val addr = cachedInetAddress
                    if (addr != null) {
                        val dp = DatagramPacket(packetBytes, packetBytes.size, addr, 8888)
                        udpSocket?.send(dp)
                    }
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun dp(value: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            resources.displayMetrics
        ).toInt()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showBubbleOverlay() {
        if (bubbleRootView != null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Baloncuk gösterilemedi: 'Diğer uygulamaların üzerinde göster' izni yok")
            return
        }

        currentActiveOverlayStyle = overlayStyle
        currentActiveOverlayLang = lang
        if (overlayStyle == 1) {
            showTripleCircleOverlay()
        } else {
            showCapsuleCardOverlay()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showCapsuleCardOverlay() {
        val wm = windowManager ?: return
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val maxOverlayWidth = (resources.displayMetrics.widthPixels * 0.88f)
            .toInt()
            .coerceAtLeast(dp(180f))
        val capsuleWidth = dp(226f).coerceAtMost(maxOverlayWidth)

        val params = WindowManager.LayoutParams(
            capsuleWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16f)
            y = dp(140f)
        }
        bubbleLayoutParams = params

        val ovBg = withAlphaInt(overlayBgColor, 235)
        val ovBorder = withAlphaInt(overlayBorderColor, 215)
        val ovTxt = contrastTextInt(overlayBgColor)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12f), dp(10f), dp(12f), dp(10f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24f).toFloat()
                setColor(ovBg)
                setStroke(dp(1.8f), ovBorder)
            }
        }

        // Üst Satır: Başlık + SIFIRLA + Kapat
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val titleTv = TextView(this).apply {
            text = if (isEn()) "🚗 CHILL DRIVE" else "🚗 RAHAT SÜRÜŞ"
            setTextColor(withAlphaInt(overlayBorderColor, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setOnClickListener {
                // Uygulamayı tekrar öne getir
                try {
                    val launchIntent = Intent(this@Mod8BackgroundService, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(launchIntent)
                } catch (_: Exception) {
                }
            }
        }

        val resetBtn = TextView(this).apply {
            text = if (isEn()) "RESET" else "SIFIRLA"
            setTextColor(withAlphaInt(overlayBorderColor, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8f), dp(4f), dp(8f), dp(4f))
            background = GradientDrawable().apply {
                cornerRadius = dp(10f).toFloat()
                setColor(withAlphaInt(overlayBorderColor, 45))
                setStroke(dp(1f), withAlphaInt(overlayBorderColor, 145))
            }
            setOnClickListener {
                recalibrateNow()
            }
        }

        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#FF5252"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(dp(7f), dp(2f), dp(7f), dp(2f))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = dp(6f)
            }
            layoutParams = lp
            background = GradientDrawable().apply {
                cornerRadius = dp(12f).toFloat()
                setColor(Color.parseColor("#33FF5252"))
                setStroke(dp(1f), Color.parseColor("#FF5252"))
            }
            setOnClickListener {
                onOverlayClosedByUserCallback?.invoke()
                stopEverything()
                stopSelf()
            }
        }

        headerRow.addView(titleTv)
        headerRow.addView(resetBtn)
        headerRow.addView(closeBtn)
        root.addView(headerRow)

        // Direksiyon Mini Çubuğu
        val sBar = SteeringBarView(
            this,
            barBgColor = withAlphaInt(ovTxt, 32),
            fillColorInt = withAlphaInt(overlaySteerColor, 255),
            centerColorInt = withAlphaInt(ovTxt, 110)
        ).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(9f)
            ).apply {
                topMargin = dp(8f)
                bottomMargin = dp(6f)
            }
        }
        steeringBarView = sBar
        root.addView(sBar)

        // Gaz / Direksiyon / Fren Yüzde Satırı
        val infoRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val bTv = TextView(this).apply {
            text = if (isEn()) "BRK 0%" else "FREN 0%"
            setTextColor(withAlphaInt(overlayBrakeColor, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            typeface = Typeface.MONOSPACE
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val sTv = TextView(this).apply {
            text = if (isEn()) "STR 0%" else "DİR 0%"
            setTextColor(withAlphaInt(ovTxt, 215))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val gTv = TextView(this).apply {
            text = if (isEn()) "GAS 0%" else "GAZ 0%"
            setTextColor(withAlphaInt(overlayGasColor, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        brakeTextView = bTv
        steerTextView = sTv
        gasTextView = gTv

        infoRow.addView(bTv)
        infoRow.addView(sTv)
        infoRow.addView(gTv)
        root.addView(infoRow)

        // Vites - / Vites + Satırı
        val gRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            visibility = if (showGearButtons) View.VISIBLE else View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(8f)
            }
        }

        fun createGearBg(active: Boolean): GradientDrawable {
            return GradientDrawable().apply {
                cornerRadius = dp(11f).toFloat()
                setColor(
                    if (active) withAlphaInt(overlayGearBtnColor, 150)
                    else withAlphaInt(ovTxt, 24)
                )
                setStroke(
                    dp(1f),
                    if (active) ovTxt else withAlphaInt(overlayGearBtnColor, 165)
                )
            }
        }

        val gearDownBtn = TextView(this).apply {
            text = if (isEn()) "GEAR -" else "VİTES -"
            setTextColor(ovTxt)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(6f), 0, dp(6f))
            background = createGearBg(false)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = dp(4f)
            }
            setOnTouchListener { v, ev ->
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        gearDownPressed = true
                        v.background = createGearBg(true)
                        sendCurrentPacket()
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        gearDownPressed = false
                        v.background = createGearBg(false)
                        sendCurrentPacket()
                    }
                }
                true
            }
        }

        val gearUpBtn = TextView(this).apply {
            text = if (isEn()) "GEAR +" else "VİTES +"
            setTextColor(ovTxt)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(6f), 0, dp(6f))
            background = createGearBg(false)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(4f)
            }
            setOnTouchListener { v, ev ->
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        gearUpPressed = true
                        v.background = createGearBg(true)
                        sendCurrentPacket()
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        gearUpPressed = false
                        v.background = createGearBg(false)
                        sendCurrentPacket()
                    }
                }
                true
            }
        }

        gRow.addView(gearDownBtn)
        gRow.addView(gearUpBtn)
        gearRowView = gRow
        root.addView(gRow)

        // Sürükleme (Drag) Desteği
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        val dragListener = View.OnTouchListener { _, event ->
            val lp = bubbleLayoutParams ?: return@OnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = lp.x
                    initialY = lp.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    lp.x = initialX + (event.rawX - initialTouchX).toInt()
                    lp.y = initialY + (event.rawY - initialTouchY).toInt()
                    try {
                        windowManager?.updateViewLayout(bubbleRootView, lp)
                    } catch (_: Exception) {
                    }
                    true
                }
                else -> false
            }
        }

        root.setOnTouchListener(dragListener)
        sBar.setOnTouchListener(dragListener)
        infoRow.setOnTouchListener(dragListener)

        try {
            wm.addView(root, params)
            bubbleRootView = root
            updateBubbleUi()
        } catch (e: Exception) {
            Log.e(TAG, "Baloncuk eklenemedi: $e")
        }
    }

    /**
     * Dikey sıralanmış üç ayrı yuvarlak baloncuk stili (Style 1):
     * -> Üst (küçük parça): Vites Arttır (Vites +)
     * -> Orta (ortanca parça): Sensörü Kalibre Et (Sıfırla)
     * -> Alt (küçük parça): Vites Düşür (Vites -)
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun showTripleCircleOverlay() {
        val wm = windowManager ?: return
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16f)
            y = dp(160f)
        }
        bubbleLayoutParams = params

        // Kök dikey konteyner: 3 ayrı yuvarlak dikey dizilir, arka planı tamamen saydamdır
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(4f), dp(4f), dp(4f), dp(4f))
            background = null
        }

        fun createCircleDrawableInt(bgColor: Int, strokeColor: Int, strokeWidthDp: Float): GradientDrawable {
            return GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(bgColor)
                setStroke(dp(strokeWidthDp), strokeColor)
            }
        }

        val ovCircleBg = withAlphaInt(overlayBgColor, 235)
        val ovTxt = contrastTextInt(overlayBgColor)
        val ovGearCol = withAlphaInt(overlayGearBtnColor, 255)
        val ovBorderCol = withAlphaInt(overlayBorderColor, 255)

        // 0. En Üst: Minik Kapatma Rozeti ("✕")
        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#FF5252"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 8.5f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(18f), dp(18f)).apply {
                bottomMargin = dp(5f)
            }
            background = createCircleDrawableInt(ovCircleBg, Color.parseColor("#88FF5252"), 1f)
            setOnClickListener {
                onOverlayClosedByUserCallback?.invoke()
                stopEverything()
                stopSelf()
            }
        }
        root.addView(closeBtn)

        // 1. ÜST PARÇA (Küçük Yuvarlak - 44dp): VİTES ARTTIR (Vites +)
        val normalUpBg = createCircleDrawableInt(ovCircleBg, ovGearCol, 1.8f)
        val activeUpBg = createCircleDrawableInt(withAlphaInt(ovGearCol, 160), ovTxt, 2.2f)

        val gearUpCircle = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(44f), dp(44f)).apply {
                bottomMargin = dp(6f)
            }
            background = normalUpBg

            val arrowTv = TextView(this@Mod8BackgroundService).apply {
                text = "▲"
                setTextColor(ovGearCol)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            val labelTv = TextView(this@Mod8BackgroundService).apply {
                text = if (isEn()) "G+" else "V+"
                setTextColor(ovTxt)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 7.5f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            addView(arrowTv)
            addView(labelTv)

            var isDraggingUp = false
            var startXUp = 0f
            var startYUp = 0f
            var initXUp = 0
            var initYUp = 0

            setOnTouchListener { v, ev ->
                val lp = bubbleLayoutParams ?: return@setOnTouchListener false
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        isDraggingUp = false
                        startXUp = ev.rawX
                        startYUp = ev.rawY
                        initXUp = lp.x
                        initYUp = lp.y
                        gearUpPressed = true
                        sendCurrentPacket()
                        v.background = activeUpBg
                        v.animate().scaleX(0.88f).scaleY(0.88f).setDuration(60).start()
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = abs(ev.rawX - startXUp)
                        val dy = abs(ev.rawY - startYUp)
                        if (dx > dp(7f) || dy > dp(7f)) {
                            isDraggingUp = true
                            if (gearUpPressed) {
                                gearUpPressed = false
                                sendCurrentPacket()
                            }
                            lp.x = initXUp + (ev.rawX - startXUp).toInt()
                            lp.y = initYUp + (ev.rawY - startYUp).toInt()
                            try {
                                windowManager?.updateViewLayout(bubbleRootView, lp)
                            } catch (_: Exception) {}
                        }
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(60).start()
                        v.background = normalUpBg
                        if (gearUpPressed) {
                            gearUpPressed = false
                            sendCurrentPacket()
                        }
                        true
                    }
                    else -> false
                }
            }
        }
        root.addView(gearUpCircle)

        // 2. ORTANCA PARÇA (Orta Yuvarlak - 56dp): SENSÖRÜ KALİBRE ET
        val normalMidBg = createCircleDrawableInt(ovCircleBg, ovBorderCol, 2.2f)
        val activeMidBg = createCircleDrawableInt(withAlphaInt(ovBorderCol, 90), ovTxt, 2.5f)

        val calibrateCircle = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(56f), dp(56f)).apply {
                bottomMargin = dp(6f)
            }
            background = normalMidBg

            val iconTv = TextView(this@Mod8BackgroundService).apply {
                text = "⟲"
                setTextColor(ovBorderCol)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            val labelTv = TextView(this@Mod8BackgroundService).apply {
                text = if (isEn()) "RESET" else "SIFIRLA"
                setTextColor(ovTxt)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 7.5f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            addView(iconTv)
            addView(labelTv)

            var isDraggingMid = false
            var downTime = 0L
            var midStartX = 0f
            var midStartY = 0f
            var midInitX = 0
            var midInitY = 0

            setOnTouchListener { v, ev ->
                val lp = bubbleLayoutParams ?: return@setOnTouchListener false
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        isDraggingMid = false
                        downTime = System.currentTimeMillis()
                        midStartX = ev.rawX
                        midStartY = ev.rawY
                        midInitX = lp.x
                        midInitY = lp.y
                        v.background = activeMidBg
                        v.animate().scaleX(0.9f).scaleY(0.9f).setDuration(60).start()
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = abs(ev.rawX - midStartX)
                        val dy = abs(ev.rawY - midStartY)
                        if (dx > dp(7f) || dy > dp(7f)) {
                            isDraggingMid = true
                            lp.x = midInitX + (ev.rawX - midStartX).toInt()
                            lp.y = midInitY + (ev.rawY - midStartY).toInt()
                            try {
                                windowManager?.updateViewLayout(bubbleRootView, lp)
                            } catch (_: Exception) {}
                        }
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(60).start()
                        v.background = normalMidBg
                        if (!isDraggingMid) {
                            val duration = System.currentTimeMillis() - downTime
                            if (duration >= 600) {
                                // Uzun basma: Uygulamayı öne getir
                                try {
                                    val launchIntent = Intent(this@Mod8BackgroundService, MainActivity::class.java).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    startActivity(launchIntent)
                                } catch (_: Exception) {}
                            } else {
                                // Normal tıklama: Sensörü sıfırla/kalibre et
                                recalibrateNow()
                                v.background = createCircleDrawableInt(
                                    Color.parseColor("#CC00E676"),
                                    ovTxt,
                                    2.5f
                                )
                                mainHandler.postDelayed({
                                    v.background = normalMidBg
                                }, 220)
                            }
                        }
                        true
                    }
                    else -> false
                }
            }
        }
        root.addView(calibrateCircle)

        // 3. ALT PARÇA (Küçük Yuvarlak - 44dp): VİTES DÜŞÜR (Vites -)
        val normalDownBg = createCircleDrawableInt(ovCircleBg, ovGearCol, 1.8f)
        val activeDownBg = createCircleDrawableInt(withAlphaInt(ovGearCol, 160), ovTxt, 2.2f)

        val gearDownCircle = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(44f), dp(44f))
            background = normalDownBg

            val arrowTv = TextView(this@Mod8BackgroundService).apply {
                text = "▼"
                setTextColor(ovGearCol)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            val labelTv = TextView(this@Mod8BackgroundService).apply {
                text = if (isEn()) "G-" else "V-"
                setTextColor(ovTxt)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 7.5f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }
            addView(arrowTv)
            addView(labelTv)

            var isDraggingDown = false
            var startXDown = 0f
            var startYDown = 0f
            var initXDown = 0
            var initYDown = 0

            setOnTouchListener { v, ev ->
                val lp = bubbleLayoutParams ?: return@setOnTouchListener false
                when (ev.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        isDraggingDown = false
                        startXDown = ev.rawX
                        startYDown = ev.rawY
                        initXDown = lp.x
                        initYDown = lp.y
                        gearDownPressed = true
                        sendCurrentPacket()
                        v.background = activeDownBg
                        v.animate().scaleX(0.88f).scaleY(0.88f).setDuration(60).start()
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = abs(ev.rawX - startXDown)
                        val dy = abs(ev.rawY - startYDown)
                        if (dx > dp(7f) || dy > dp(7f)) {
                            isDraggingDown = true
                            if (gearDownPressed) {
                                gearDownPressed = false
                                sendCurrentPacket()
                            }
                            lp.x = initXDown + (ev.rawX - startXDown).toInt()
                            lp.y = initYDown + (ev.rawY - startYDown).toInt()
                            try {
                                windowManager?.updateViewLayout(bubbleRootView, lp)
                            } catch (_: Exception) {}
                        }
                        true
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(60).start()
                        v.background = normalDownBg
                        if (gearDownPressed) {
                            gearDownPressed = false
                            sendCurrentPacket()
                        }
                        true
                    }
                    else -> false
                }
            }
        }
        root.addView(gearDownCircle)

        try {
            wm.addView(root, params)
            bubbleRootView = root
        } catch (e: Exception) {
            Log.e(TAG, "Dikey 3'lü baloncuk eklenemedi: $e")
        }
    }

    private fun updateBubbleUi() {
        val root = bubbleRootView ?: return
        if (!root.isAttachedToWindow) return

        val steerPct = (currentSteering * 100.0).toInt()
        val gasPct = (currentGas * 100.0).toInt()
        val brakePct = (currentBrake * 100.0).toInt()

        val en = isEn()
        if (brakePct != lastDisplayedBrakePct) {
            lastDisplayedBrakePct = brakePct
            brakeTextView?.text = if (en) "BRK $brakePct%" else "FREN $brakePct%"
        }
        if (steerPct != lastDisplayedSteerPct) {
            lastDisplayedSteerPct = steerPct
            steerTextView?.text = if (en) "STR $steerPct%" else "DİR $steerPct%"
            steeringBarView?.steering = currentSteering.toFloat()
            steeringBarView?.invalidate()
        }
        if (gasPct != lastDisplayedGasPct) {
            lastDisplayedGasPct = gasPct
            gasTextView?.text = if (en) "GAS $gasPct%" else "GAZ $gasPct%"
        }
    }

    private fun hideBubbleOverlay() {
        val view = bubbleRootView ?: return
        bubbleRootView = null
        steeringBarView = null
        brakeTextView = null
        steerTextView = null
        gasTextView = null
        gearRowView = null
        lastDisplayedSteerPct = Int.MIN_VALUE
        lastDisplayedGasPct = Int.MIN_VALUE
        lastDisplayedBrakePct = Int.MIN_VALUE
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
        }
    }

    private class SteeringBarView(
        context: Context,
        barBgColor: Int = Color.parseColor("#1A1A2E"),
        fillColorInt: Int = Color.parseColor("#40E0D0"),
        centerColorInt: Int = Color.parseColor("#55FFFFFF"),
    ) : View(context) {
        var steering: Float = 0f
        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = barBgColor
            style = Paint.Style.FILL
        }
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fillColorInt
            style = Paint.Style.FILL
        }
        private val centerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = centerColorInt
            strokeWidth = 3f
        }
        private val rect = RectF()

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val r = h / 2f

            rect.set(0f, 0f, w, h)
            canvas.drawRoundRect(rect, r, r, bgPaint)

            val center = w / 2f
            val clamped = steering.coerceIn(-1f, 1f)
            val ind = center + clamped * center
            val left = min(center, ind)
            val right = max(center, ind)

            if (right - left > 1f) {
                rect.set(left, 0f, right, h)
                canvas.drawRoundRect(rect, r, r, fillPaint)
            }

            canvas.drawLine(center, 0f, center, h, centerPaint)
        }
    }

    private fun acquireLocks() {
        try {
            if (wakeLock == null) {
                val pm = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = pm?.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "DoYaDi::Mod8BgWakeLock"
                )?.apply {
                    setReferenceCounted(false)
                }
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(4 * 60 * 60 * 1000L)
            }
        } catch (_: Exception) {
        }

        try {
            if (wifiLock == null) {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                @Suppress("DEPRECATION")
                val lockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                } else {
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF
                }
                wifiLock = wm?.createWifiLock(lockMode, "DoYaDi::Mod8BgWifiLock")?.apply {
                    setReferenceCounted(false)
                }
            }
            if (wifiLock?.isHeld == false) {
                wifiLock?.acquire()
            }
        } catch (_: Exception) {
        }
    }

    private fun releaseLocks() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {
        }
        wakeLock = null

        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
        } catch (_: Exception) {
        }
        wifiLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val en = isEn()
            val channel = NotificationChannel(
                CHANNEL_ID,
                if (en) "Mode 8 Background Drive" else "Mod 8 Arka Plan Sürüşü",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = if (en) {
                    "Active only while Mode 8 (Chill Drive) runs in the background"
                } else {
                    "Sadece Mod 8 (Rahat Sürüş) arka planda çalışırken aktif olur"
                }
                setShowBadge(false)
            }
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val overlayAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            Settings.canDrawOverlays(this)
        val en = isEn()
        val contentText = when {
            !isInBackgroundMode -> if (en) {
                "Ready: Driving continues when you minimize the app"
            } else {
                "Hazır: Uygulamayı arka plana attığınızda sürüş devam eder"
            }
            overlayAllowed -> if (en) {
                "Floating capsule bubble & sensor driving active in background"
            } else {
                "Arka planda kapsül baloncuk ve sensör sürüşü aktif"
            }
            else -> if (en) {
                "Overlay permission missing — use controls here"
            } else {
                "Baloncuk izni yok — kontrolleri buradaki butonlardan kullanın"
            }
        }

        fun serviceAction(action: String, requestCode: Int): PendingIntent {
            val i = Intent(this, Mod8BackgroundService::class.java).apply {
                this.action = action
            }
            return PendingIntent.getService(this, requestCode, i, pendingFlags)
        }

        builder
            .setContentTitle(if (en) "Mode 8 — Chill Drive" else "Mod 8 — Rahat Sürüş")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        // Android 5.0-6.0 (API 21-23) sürümlerinde 0 ikon değeri aksiyon butonunu gizleyebildiği/çökertebildiği için geçerli ikon verilir
        val actionIcon = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) 0 else R.mipmap.ic_launcher

        @Suppress("DEPRECATION")
        builder
            .addAction(Notification.Action.Builder(actionIcon, if (en) "RESET" else "SIFIRLA", serviceAction(ACTION_RECALIBRATE, 11)).build())
            .addAction(Notification.Action.Builder(actionIcon, if (en) "GEAR -" else "VİTES -", serviceAction(ACTION_GEAR_DOWN, 12)).build())
            .addAction(Notification.Action.Builder(actionIcon, if (en) "GEAR +" else "VİTES +", serviceAction(ACTION_GEAR_UP, 13)).build())

        return builder.build()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        stopEverything()
        foregroundStarted = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
