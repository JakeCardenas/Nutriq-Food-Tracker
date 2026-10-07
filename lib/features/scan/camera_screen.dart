import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/labels.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sheet.dart';
import 'meal_flows.dart';

enum _CameraState { loading, ready, denied, unavailable }

/// Full-screen meal camera: live preview with a framing guide, shutter, flash
/// and photo library. A captured photo is saved on this phone as a draft and
/// analyzed in the background — the person reviews it on Today before logging.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.loadCameras = availableCameras});

  /// Injectable for tests (the default asks the camera plugin).
  final Future<List<CameraDescription>> Function() loadCameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  _CameraState _state = _CameraState.loading;
  FlashMode _flash = FlashMode.off;
  bool _capturing = false;
  bool _shutterFlash = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed && controller == null && _state != _CameraState.unavailable) {
      _init();
    }
  }

  Future<void> _init() async {
    try {
      // A camera plugin that never answers shouldn't leave a spinner forever.
      final cameras = await widget.loadCameras().timeout(const Duration(seconds: 8));
      if (cameras.isEmpty) return _setState(_CameraState.unavailable);
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flash).catchError((Object _) {});
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _setState(_CameraState.ready);
    } on CameraException catch (e) {
      _setState(e.code.startsWith('CameraAccess') ? _CameraState.denied : _CameraState.unavailable);
    } catch (_) {
      _setState(_CameraState.unavailable);
    }
  }

  void _setState(_CameraState s) {
    if (mounted) setState(() => _state = s);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) return;
    // The white shutter flash is skipped with Reduce Motion (no sudden brightness change).
    final flash = !MediaQuery.of(context).disableAnimations;
    setState(() {
      _capturing = true;
      _shutterFlash = flash;
    });
    HapticFeedback.mediumImpact();
    Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _shutterFlash = false);
    });
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      final toDescribe = await MealFlows.startDraft(context, file.path);
      if (mounted) Navigator.pop(context, toDescribe);
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        showToast(context, 'Couldn’t take the photo. Try again, or choose one from your library.');
      }
    }
  }

  Future<void> _library() async {
    if (_busy) return;
    setState(() => _busy = true);
    final chosen = await MealFlows.choosePhoto(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (chosen.picked) Navigator.pop(context, chosen.toDescribe);
  }

  Future<void> _manual() async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await MealFlows.openManual(navigator.context);
  }

  Future<void> _toggleFlash() async {
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {
      if (mounted) showToast(context, 'Flash isn’t available on this camera.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_state == _CameraState.ready && controller != null) _Preview(controller: controller),
            if (_state == _CameraState.ready) const _FrameGuide(),
            if (_state == _CameraState.loading)
              const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            if (_state == _CameraState.denied || _state == _CameraState.unavailable)
              _NoCamera(denied: _state == _CameraState.denied, busy: _busy, onLibrary: _library, onManual: _manual),
            AnimatedOpacity(
              opacity: _shutterFlash ? 0.7 : 0,
              duration: const Duration(milliseconds: 90),
              child: const IgnorePointer(child: ColoredBox(color: Colors.white)),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      CircleButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close camera',
                        onPhoto: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Nutriq',
                              textAlign: TextAlign.center,
                              style: NqText.headline.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            if (AppScope.of(context).analysis.isDemo) ...[const SizedBox(height: 6), const _DemoPill()],
                            if (!AppScope.of(context).analysis.recognizesPhotos) ...[
                              const SizedBox(height: 6),
                              const _DescribeNextPill(),
                            ],
                          ],
                        ),
                      ),
                      CircleButton(
                        icon: Icons.question_mark_rounded,
                        tooltip: 'Photo tips',
                        onPhoto: true,
                        onPressed: () => _showTips(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_state == _CameraState.ready)
              Align(
                alignment: Alignment.bottomCenter,
                child: _Controls(
                  flashOn: _flash == FlashMode.torch,
                  capturing: _capturing,
                  libraryBusy: _busy,
                  onFlash: _toggleFlash,
                  onShutter: _capture,
                  onLibrary: _library,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTips(BuildContext context) {
    final demo = AppScope.of(context).analysis.isDemo;
    showNqSheet<void>(
      context,
      title: 'Getting a good estimate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (demo) ...[
            const NoticeCard(
              tone: NoticeTone.demo,
              icon: Icons.science_outlined,
              title: 'Demo analysis',
              message: 'Food recognition isn’t connected yet. You’ll get a sample meal to edit — it isn’t based on your photo.',
            ),
            const SizedBox(height: NqSpace.lg),
          ],
          for (final (icon, text) in const [
            (Icons.wb_sunny_outlined, 'Use good light and avoid strong shadows.'),
            (Icons.crop_free_rounded, 'Fit the whole plate inside the frame, shot from slightly above.'),
            (Icons.fact_check_outlined, 'You’ll review and correct every food before anything is logged.'),
            (Icons.lock_outline_rounded, 'Your photo stays on this phone and is never uploaded.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: NqSpace.md),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: NqColors.ink),
                  const SizedBox(width: 14),
                  Expanded(child: Text(text, style: NqText.body.copyWith(fontSize: 16))),
                ],
              ),
            ),
          const SizedBox(height: NqSpace.sm),
          PrimaryButton(label: 'Got it', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    // previewSize is reported in landscape; the app is portrait-only.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.height, height: size.width, child: CameraPreview(controller)),
      ),
    );
  }
}

/// White corner brackets that frame the plate.
class _FrameGuide extends StatelessWidget {
  const _FrameGuide();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: const Alignment(0, -0.18),
      child: FractionallySizedBox(
        widthFactor: 0.78,
        child: AspectRatio(aspectRatio: 0.9, child: CustomPaint(painter: _BracketPainter())),
      ),
    ),
  );
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 38.0;
    const r = 22.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    Path corner(Offset a, Offset c, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(c.dx + (a.dx - c.dx).sign * r, c.dy + (a.dy - c.dy).sign * r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + (b.dx - c.dx).sign * r, c.dy + (b.dy - c.dy).sign * r)
      ..lineTo(b.dx, b.dy);
    canvas
      ..drawPath(corner(const Offset(0, len + r), Offset.zero, const Offset(len + r, 0)), paint)
      ..drawPath(corner(Offset(w - len - r, 0), Offset(w, 0), Offset(w, len + r)), paint)
      ..drawPath(corner(Offset(w, h - len - r), Offset(w, h), Offset(w - len - r, h)), paint)
      ..drawPath(corner(Offset(len + r, h), Offset(0, h), Offset(0, h - len - r)), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => false;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.flashOn,
    required this.capturing,
    required this.libraryBusy,
    required this.onFlash,
    required this.onShutter,
    required this.onLibrary,
  });

  final bool flashOn;
  final bool capturing;
  final bool libraryBusy;
  final VoidCallback onFlash;
  final VoidCallback onShutter;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant_rounded, size: 18, color: NqColors.ink),
                const SizedBox(width: 8),
                Text('Scan food', style: NqText.subhead.copyWith(color: NqColors.ink)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleButton(
                icon: flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                tooltip: flashOn ? 'Turn light off' : 'Turn light on',
                onPhoto: true,
                size: 48,
                onPressed: onFlash,
              ),
              Semantics(
                button: true,
                label: 'Take photo',
                child: Pressable(
                  onTap: capturing ? null : onShutter,
                  scale: 0.92,
                  child: Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: capturing ? Colors.white54 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              CircleButton(
                icon: Icons.photo_library_outlined,
                tooltip: 'Choose from library',
                onPhoto: true,
                size: 48,
                onPressed: libraryBusy ? null : onLibrary,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Shown when the camera can't be used (denied, Simulator, or no camera).
class _NoCamera extends StatelessWidget {
  const _NoCamera({required this.denied, required this.busy, required this.onLibrary, required this.onManual});

  final bool denied;
  final bool busy;
  final VoidCallback onLibrary;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 24),
      child: Column(
        children: [
          const Spacer(),
          Icon(denied ? Icons.no_photography_outlined : Icons.photo_camera_outlined, color: Colors.white, size: 44),
          const SizedBox(height: 18),
          Text(
            denied ? 'Camera access is off' : 'Camera isn’t available',
            textAlign: TextAlign.center,
            style: NqText.title.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            denied
                ? 'To scan meals, allow camera access in Settings → Privacy & Security → Camera → Nutriq. '
                      'You can still choose a photo or log the meal by hand.'
                : 'This device has no camera Nutriq can use (for example, the iOS Simulator). '
                      'Choose a photo from your library or log the meal by hand.',
            textAlign: TextAlign.center,
            style: NqText.callout.copyWith(color: Colors.white70),
          ),
          const Spacer(),
          Pressable(
            onTap: busy ? null : onLibrary,
            semanticLabel: 'Choose from library',
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, color: NqColors.ink, size: 20),
                    const SizedBox(width: 8),
                    Text('Choose from library', style: NqText.headline.copyWith(color: NqColors.ink)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          QuietButton(label: 'Log manually', color: Colors.white, onPressed: onManual),
        ],
      ),
    ),
  );
}

/// Says, on the camera itself, that results will be samples rather than analysis.
class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Demo analysis: results are samples, not based on your photo',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: NqColors.demoFill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 13, color: NqColors.demoInk),
          const SizedBox(width: 4),
          Text(
            'Demo analysis',
            style: NqText.caption.copyWith(color: NqColors.demoInk, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

/// Says up front that the photo is kept and the person types what's in it.
class _DescribeNextPill extends StatelessWidget {
  const _DescribeNextPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
    child: Text(
      'You’ll type what’s in it next',
      style: NqText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}
