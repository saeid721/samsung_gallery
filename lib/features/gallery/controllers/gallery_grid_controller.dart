import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GalleryGridController extends GetxController {
  static const _kPrefKey  = 'gallery.columns';
  static const minColumns = 1;
  static const maxColumns = 20;
  static const defaultColumns = 3;

  // ── Reactive state ────────────────────────────────────────────
  final RxInt  columnsCount    = defaultColumns.obs;
  final RxBool isZooming       = false.obs;   // shows column-count HUD

  // ── Internal gesture tracking ─────────────────────────────────
  double _startScale          = 1.0;
  int    _startColumns        = defaultColumns;

  // How much scale ratio equals one column step.
  // 1.25 ≈ Samsung Gallery feel.
  static const double _kStepRatio = 1.25;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  // ── Public gesture API ────────────────────────────────────────

  void onScaleStart(double initialScale) {
    _startScale   = initialScale.clamp(0.01, double.infinity);
    _startColumns = columnsCount.value;
    isZooming.value = true;
  }

  void onScaleUpdate(double scale) {
    final ratio    = scale / _startScale;
    // log base _kStepRatio tells us how many steps we've moved
    final steps    = _log(ratio, _kStepRatio);
    // Positive steps = zooming in = fewer columns
    final newCount = (_startColumns - steps.round())
        .clamp(minColumns, maxColumns);
    if (newCount != columnsCount.value) {
      columnsCount.value = newCount;
    }
  }

  void onScaleEnd() {
    isZooming.value = false;
    _persist();
  }

  // ── Direct setters ────────────────────────────────────────────
  void setColumns(int n) {
    columnsCount.value = n.clamp(minColumns, maxColumns);
    _persist();
  }

  // ── Math helper ───────────────────────────────────────────────
  static double _log(double x, double base) {
    if (x <= 0 || base <= 0 || base == 1) return 0;
    return math.log(x) / math.log(base);
  }

  // ── Persistence ───────────────────────────────────────────────
  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt(_kPrefKey);
      if (v != null) {
        columnsCount.value = v.clamp(minColumns, maxColumns);
        _startColumns      = columnsCount.value;
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kPrefKey, columnsCount.value);
    } catch (_) {}
  }
}