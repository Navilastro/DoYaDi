import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';

/// Oyun akışını ve sürüş hissini korumak için SADECE Geçiş Reklamlarını (Interstitial Ad)
/// önceden yükleyerek (Pre-load) yöneten servis.
class AdService {
  AdService._internal();
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  /// Google Test Android Interstitial Unit ID.
  /// Canlıya alırken kendi AdMob Interstitial Ad Unit ID'niz ile değiştirin.
  static const String androidInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Google Test iOS Interstitial Unit ID.
  static const String iosInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  InterstitialAd? _interstitialAd;
  bool _isInitialized = false;
  bool _isLoadingAd = false;
  bool _isAdFreeOrPro = false;
  Timer? _delayedPreloadTimer;

  bool get isAdReady => _interstitialAd != null;
  bool get isAdFreeOrPro => _isAdFreeOrPro;

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get _adUnitId => Platform.isIOS
      ? iosInterstitialAdUnitId
      : androidInterstitialAdUnitId;

  /// Abonelik durumu değiştiğinde (Ad-Free veya PRO aktif olduğunda) çağrılır.
  void updateSubscriptionStatus({required bool isAdFreeOrPro}) {
    _isAdFreeOrPro = isAdFreeOrPro;
    if (_isAdFreeOrPro) {
      _delayedPreloadTimer?.cancel();
      _delayedPreloadTimer = null;
      _interstitialAd?.dispose();
      _interstitialAd = null;
    } else if (_isInitialized) {
      preloadInterstitial();
    }
  }

  /// MobileAds SDK'sını başlatır ve ilk geçiş reklamını önceden yükler.
  Future<void> initialize() async {
    if (AppConfig.instance.isVIP || _isInitialized || !_isMobilePlatform) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      if (!_isAdFreeOrPro) {
        preloadInterstitial();
      }
    } catch (e) {
      debugPrint('AdService.initialize error: $e');
    }
  }

  /// Geçiş reklamını kullanıcıyı bekletmeden göstermek için arka planda önceden yükler.
  void preloadInterstitial() {
    if (AppConfig.instance.isVIP ||
        _isAdFreeOrPro ||
        !_isMobilePlatform ||
        _isLoadingAd ||
        _interstitialAd != null) {
      return;
    }
    _isLoadingAd = true;
    try {
      InterstitialAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _isLoadingAd = false;
            if (_isAdFreeOrPro) {
              ad.dispose();
              return;
            }
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _isLoadingAd = false;
            _interstitialAd = null;
            debugPrint('InterstitialAd failed to load: ${error.message}');
          },
        ),
      );
    } catch (e) {
      _isLoadingAd = false;
      _interstitialAd = null;
      debugPrint('InterstitialAd.load exception: $e');
    }
  }

  /// Kullanıcı Ad-Free veya PRO DEĞİLSE önceden yüklenmiş geçiş reklamını gösterir,
  /// reklam kapandığında (veya kullanıcı zaten reklamsızsa / reklam henüz hazır değilse
  /// kullanıcıyı bekletmeden anında) [onComplete] geri çağrısını tetikler.
  void showInterstitial({
    required VoidCallback onComplete,
    bool? isAdFree,
  }) {
    if (AppConfig.instance.isVIP) {
      onComplete();
      return;
    }
    final skipAds = (isAdFree ?? false) || _isAdFreeOrPro;
    if (skipAds || !_isMobilePlatform) {
      onComplete();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      // Kullanıcıyı bekletmemek için hemen devam et ve sonraki sefer için reklamı yükle.
      preloadInterstitial();
      onComplete();
      return;
    }

    _interstitialAd = null;
    bool completed = false;
    void finish({bool deferPreload = false}) {
      if (completed) return;
      completed = true;
      // Android tam ekran reklam Activity'si kapandıktan hemen sonraki karede
      // rota geçişini başlatarak yüzey geçişi kaynaklı takılmayı önler.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onComplete();
      });
      if (deferPreload && !_isAdFreeOrPro) {
        // Yeni reklam yüklemesini sürüş ekranı açılışını tıkamaması için 3 sn ertele.
        _delayedPreloadTimer?.cancel();
        _delayedPreloadTimer = Timer(const Duration(seconds: 3), () {
          preloadInterstitial();
        });
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd shownAd) {
        shownAd.dispose();
        finish(deferPreload: true);
      },
      onAdFailedToShowFullScreenContent: (
        InterstitialAd shownAd,
        AdError error,
      ) {
        shownAd.dispose();
        finish(deferPreload: true);
      },
    );

    try {
      ad.show();
    } catch (e) {
      ad.dispose();
      finish(deferPreload: true);
    }
  }
}

