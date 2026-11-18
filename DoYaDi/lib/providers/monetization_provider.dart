import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/utils/app_translations.dart';
import '../services/ad_service.dart';

/// Otomatik yenilenen yıllık abonelik durumlarını (`isAdFree` ve `isPro`)
/// `in_app_purchase` altyapısı üzerinden yöneten Provider.
class MonetizationProvider extends ChangeNotifier {
  static const String kAdFreeYearlyProductId = 'doyadi_adfree_yearly';
  static const String kProYearlyProductId = 'doyadi_pro_yearly';
  static const Set<String> kSubscriptionProductIds = {
    kAdFreeYearlyProductId,
    kProYearlyProductId,
  };

  static const String _prefAdFreeKey = 'sub_is_ad_free_v1';
  static const String _prefProKey = 'sub_is_pro_v1';

  /// Uygulama genelinde hata/iptal/yükseltme durumlarında SnackBar gösterebilmek için
  /// MaterialApp.scaffoldMessengerKey'e bağlanır.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _restoreReconcileTimer;

  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _isStoreAvailable = false;
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _isAdFree = false;
  bool _isPro = false;
  String? _statusMessage;
  List<ProductDetails> _products = [];
  final Set<String> _restoredActiveProductIds = <String>{};

  /// Yıllık PRO aboneliği aktif mi? (Admin/VIP flavor'da otomatik true)
  bool get isPro => AppConfig.instance.isVIP || _isPro;

  /// Yıllık Reklam Kaldırma aboneliği aktif mi?
  /// Admin/VIP veya PRO olan kullanıcı otomatik olarak Ad-Free sayılır.
  bool get isAdFree => AppConfig.instance.isVIP || _isAdFree || _isPro;

  bool get isLoading => _isLoading;
  bool get isStoreAvailable => _isStoreAvailable;
  String? get statusMessage => _statusMessage;
  List<ProductDetails> get products => List.unmodifiable(_products);

  ProductDetails? get adFreeProduct {
    for (final p in _products) {
      if (p.id == kAdFreeYearlyProductId) return p;
    }
    return null;
  }

  ProductDetails? get proProduct {
    for (final p in _products) {
      if (p.id == kProYearlyProductId) return p;
    }
    return null;
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (_isDisposed) return;
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Önbellekten abonelik durumunu yükler, gerçek zamanlı satın alma akışını
  /// dinler ve açılışta `restorePurchases()` tetikleyerek lisansları doğrular.
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    _isInitialized = true;

    if (AppConfig.instance.isVIP) {
      _isAdFree = true;
      _isPro = true;
      AdService().updateSubscriptionStatus(isAdFreeOrPro: true);
      _safeNotifyListeners();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _isAdFree = prefs.getBool(_prefAdFreeKey) ?? false;
      _isPro = prefs.getBool(_prefProKey) ?? false;
      AdService().updateSubscriptionStatus(isAdFreeOrPro: isAdFree);
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('MonetizationProvider cache load error: $e');
    }

    try {
      await _purchaseSubscription?.cancel();
      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () {
          _purchaseSubscription?.cancel();
          _purchaseSubscription = null;
        },
        onError: (Object error) {
          _isLoading = false;
          _isRestoring = false;
          _statusMessage =
              '${AppTranslations.getText('purchase_error_msg')} $error';
          _showSnackBar(_statusMessage!, isError: true);
          _safeNotifyListeners();
        },
      );

      _isStoreAvailable = await _iap.isAvailable();
      if (_isStoreAvailable) {
        await queryProducts();
        // Açılışta Lisans Kontrolü (Startup Validation):
        // İade edilen veya süresi dolan abonelikleri yakalamak için
        // Google Play önbelleğindeki aktif abonelikleri otomatik doğrula.
        await restorePurchases(isStartupValidation: true);
      }
    } catch (e) {
      debugPrint('MonetizationProvider store init error: $e');
      _isStoreAvailable = false;
    }
    _safeNotifyListeners();
  }

  Future<void> queryProducts() async {
    try {
      final response = await _iap.queryProductDetails(kSubscriptionProductIds);
      _products = response.productDetails;
      if (response.error != null) {
        _statusMessage = response.error!.message;
      }
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('queryProducts error: $e');
    }
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    if (_isDisposed) return;
    bool changed = false;

    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _isLoading = true;
          _statusMessage = AppTranslations.getText('purchase_pending_msg');
          changed = true;
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _isLoading = false;
          if (purchaseDetails.productID == kProYearlyProductId) {
            _isPro = true;
            _restoredActiveProductIds.add(kProYearlyProductId);
            changed = true;
            if (purchaseDetails.status == PurchaseStatus.purchased) {
              _statusMessage = AppTranslations.getText(
                'purchase_success_pro_msg',
              );
              _showSnackBar(_statusMessage!);
            }
          } else if (purchaseDetails.productID == kAdFreeYearlyProductId) {
            _isAdFree = true;
            _restoredActiveProductIds.add(kAdFreeYearlyProductId);
            changed = true;
            if (purchaseDetails.status == PurchaseStatus.purchased) {
              _statusMessage = AppTranslations.getText(
                'purchase_success_adfree_msg',
              );
              _showSnackBar(_statusMessage!);
            }
          }

          // Google Play'in 3 gün sonra otomatik iade (auto-refund) yapmaması
          // için satın alma işlemini kesinlikle onayla / tamamla.
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (e) {
              debugPrint('completePurchase error: $e');
            }
          }
          await _persistSubscriptionFlags();
          AdService().updateSubscriptionStatus(isAdFreeOrPro: isAdFree);
          break;

        case PurchaseStatus.error:
          _isLoading = false;
          final errDetail =
              purchaseDetails.error?.message ?? AppTranslations.getText('error');
          _statusMessage =
              '${AppTranslations.getText('purchase_error_msg')} $errDetail';
          _showSnackBar(_statusMessage!, isError: true);
          changed = true;
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (e) {
              debugPrint('completePurchase on error failed: $e');
            }
          }
          break;

        case PurchaseStatus.canceled:
          _isLoading = false;
          _statusMessage = AppTranslations.getText('purchase_canceled_msg');
          _showSnackBar(_statusMessage!);
          changed = true;
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (e) {
              debugPrint('completePurchase on cancel failed: $e');
            }
          }
          break;
      }
    }

    if (_isRestoring) {
      // Restored eventleri geldiğinde kısa bir debounce sonrası aktif abonelikleri eşleştir.
      _scheduleRestoreReconcile(delay: const Duration(milliseconds: 350));
    }

    if (changed) {
      _safeNotifyListeners();
    }
  }

  void _scheduleRestoreReconcile({required Duration delay}) {
    _restoreReconcileTimer?.cancel();
    _restoreReconcileTimer = Timer(delay, () {
      _reconcileRestoredSubscriptions();
    });
  }

  Future<void> _reconcileRestoredSubscriptions() async {
    if (_isDisposed || !_isRestoring) return;
    _isRestoring = false;
    _isLoading = false;

    final bool hadAnyPlan = isPro || isAdFree;
    final bool hasActivePro =
        _restoredActiveProductIds.contains(kProYearlyProductId);
    final bool hasActiveAdFree =
        _restoredActiveProductIds.contains(kAdFreeYearlyProductId);

    final bool changed =
        (_isPro != hasActivePro) || (_isAdFree != hasActiveAdFree);

    _isPro = hasActivePro;
    _isAdFree = hasActiveAdFree;

    await _persistSubscriptionFlags();
    AdService().updateSubscriptionStatus(isAdFreeOrPro: isAdFree);

    if (hadAnyPlan && !isPro && !isAdFree) {
      _statusMessage = AppTranslations.getText('subscription_downgraded_msg');
      _showSnackBar(_statusMessage!);
    } else if (_statusMessage == AppTranslations.getText('restore_started_msg')) {
      _statusMessage = null;
    }

    if (changed || !_isDisposed) {
      _safeNotifyListeners();
    }
  }

  Future<void> _persistSubscriptionFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAdFreeKey, _isAdFree);
      await prefs.setBool(_prefProKey, _isPro);
    } catch (e) {
      debugPrint('_persistSubscriptionFlags error: $e');
    }
  }

  /// Yıllık Ad-Free aboneliğini başlatır.
  /// PRO veya Ad-Free zaten aktifse alt paket koruması gereği işlem yapmaz.
  Future<void> buyAdFree() async {
    if (isAdFree || _isLoading) return;
    await _purchaseProduct(kAdFreeYearlyProductId);
  }

  /// Yıllık PRO aboneliğini başlatır.
  Future<void> buyPro() async {
    if (isPro || _isLoading) return;
    await _purchaseProduct(kProYearlyProductId);
  }

  Future<void> _purchaseProduct(String productId) async {
    if (_isDisposed) return;
    _statusMessage = null;
    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (!_isStoreAvailable) {
        _isStoreAvailable = await _iap.isAvailable();
      }
      if (!_isStoreAvailable) {
        _isLoading = false;
        _statusMessage = 'Store is unavailable on this device.';
        _showSnackBar(_statusMessage!, isError: true);
        _safeNotifyListeners();
        return;
      }

      if (_products.isEmpty) {
        await queryProducts();
      }

      ProductDetails? targetProduct;
      for (final p in _products) {
        if (p.id == productId) {
          targetProduct = p;
          break;
        }
      }

      if (targetProduct == null) {
        _isLoading = false;
        _statusMessage = 'Subscription product ($productId) not found.';
        _showSnackBar(_statusMessage!, isError: true);
        _safeNotifyListeners();
        return;
      }

      final param = PurchaseParam(productDetails: targetProduct);
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _isLoading = false;
      _statusMessage = '${AppTranslations.getText('purchase_error_msg')} $e';
      _showSnackBar(_statusMessage!, isError: true);
      _safeNotifyListeners();
    }
  }

  /// Cihazda daha önce yapılmış aktif abonelikleri Google Play / App Store
  /// üzerinden sorgular. İade edilmiş veya süresi dolmuş abonelikler aktif
  /// listede dönmediği için ilgili üyelik otomatik olarak `false` yapılır.
  Future<void> restorePurchases({bool isStartupValidation = false}) async {
    if (_isDisposed) return;

    if (!isStartupValidation) {
      _statusMessage = AppTranslations.getText('restore_started_msg');
      _isLoading = true;
      _safeNotifyListeners();
    }

    try {
      if (!_isStoreAvailable) {
        _isStoreAvailable = await _iap.isAvailable();
      }
      if (!_isStoreAvailable) {
        _isLoading = false;
        if (!isStartupValidation) {
          _statusMessage = 'Store is unavailable on this device.';
        }
        _safeNotifyListeners();
        return;
      }

      _isRestoring = true;
      _restoredActiveProductIds.clear();
      // Stream hiç event döndürmezse (tüm abonelikler iptal/iade/süresi dolmuşsa)
      // kısa süre sonra otomatik olarak ücretsiz sürüme düşürmeyi garanti et.
      _scheduleRestoreReconcile(delay: const Duration(milliseconds: 1500));

      await _iap.restorePurchases();
    } catch (e) {
      _isRestoring = false;
      _restoreReconcileTimer?.cancel();
      _isLoading = false;
      if (!isStartupValidation) {
        _statusMessage = e.toString();
      }
      _safeNotifyListeners();
    }
  }

  /// Kullanıcı limiti aştığında (ör. 4. Ayar Şablonu) veya yükseltme istediğinde
  /// Abonelik / Paywall penceresini açar ve "Satın Alımları Geri Yükle" seçeneğini sunar.
  Future<void> showPaywall(BuildContext context) async {
    if (AppConfig.instance.isVIP) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return ListenableBuilder(
          listenable: this,
          builder: (ctx, _) {
            final theme = Theme.of(ctx);
            final adFreeLabel = isPro
                ? AppTranslations.getText('btn_included_in_pro')
                : (isAdFree
                    ? AppTranslations.getText('btn_current_plan')
                    : AppTranslations.getText('btn_upgrade_ad_free'));
            final proLabel = isPro
                ? AppTranslations.getText('btn_current_plan')
                : AppTranslations.getText('btn_upgrade_pro');

            return AlertDialog(
              backgroundColor: const Color(0xFF101322),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.45),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppTranslations.getText('paywall_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppTranslations.getText('paywall_subtitle'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PaywallTierCard(
                        title: AppTranslations.getText('plan_pro_title'),
                        description: AppTranslations.getText('plan_pro_desc'),
                        priceText: proProduct?.price,
                        accentColor: Colors.amber,
                        buttonLabel: proLabel,
                        onPressed: (isPro || _isLoading) ? null : buyPro,
                      ),
                      const SizedBox(height: 12),
                      _PaywallTierCard(
                        title: AppTranslations.getText('plan_ad_free_title'),
                        description: AppTranslations.getText(
                          'plan_ad_free_desc',
                        ),
                        priceText: adFreeProduct?.price,
                        accentColor: theme.colorScheme.primary,
                        buttonLabel: adFreeLabel,
                        onPressed:
                            (isPro || isAdFree || _isLoading) ? null : buyAdFree,
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          color: theme.colorScheme.primary,
                          backgroundColor: Colors.white12,
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading ? null : restorePurchases,
                          child: Text(
                            AppTranslations.getText('btn_restore_purchases'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restoreReconcileTimer?.cancel();
    _restoreReconcileTimer = null;
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    super.dispose();
  }
}

class _PaywallTierCard extends StatelessWidget {
  final String title;
  final String description;
  final String? priceText;
  final Color accentColor;
  final String buttonLabel;
  final VoidCallback? onPressed;

  const _PaywallTierCard({
    required this.title,
    required this.description,
    required this.accentColor,
    required this.buttonLabel,
    required this.onPressed,
    this.priceText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (priceText != null)
                Text(
                  priceText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
