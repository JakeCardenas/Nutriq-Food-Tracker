import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/models/meal.dart';
import '../../services/photo_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/labels.dart';
import '../../widgets/nutriq_mark.dart';
import '../meal_editor/meal_editor_screen.dart';

enum _Phase { choose, analyzing, failed }

/// Take or choose a meal photo, show an analyzing state, then hand off to
/// the review editor. Pops with an [EditorResult] when a meal was saved.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _Phase _phase = _Phase.choose;
  PhotoPickFailed? _pickFailure;
  String? _photo;

  AppScope get _scope => AppScope.of(context);

  Future<void> _pick(PhotoSource source) async {
    setState(() => _pickFailure = null);
    final result = await _scope.photos.pick(source);
    if (!mounted) return;
    switch (result) {
      case PhotoCancelled():
        return;
      case PhotoPickFailed():
        setState(() => _pickFailure = result);
      case PhotoPicked(:final tempPath):
        await _discardPhoto();
        final stored = await _scope.photos.persist(tempPath);
        if (!mounted) return;
        _photo = stored;
        await _analyze();
    }
  }

  Future<void> _analyze() async {
    final photo = _photo!;
    setState(() => _phase = _Phase.analyzing);
    try {
      final bytes = await _scope.photos.readBytes(photo);
      final result = await _scope.analysis.analyze(bytes);
      if (!mounted) return;
      setState(() => _phase = _Phase.choose);
      await _openEditor(
        MealEditorScreen(
          initialItems: result.items,
          photoPath: photo,
          source: result.isDemo ? MealSource.demoScan : MealSource.scan,
          demoSampleName: result.sampleName,
          emptyResult: result.items.isEmpty,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _openEditor(MealEditorScreen editor) async {
    final result = await Navigator.of(context).push<EditorResult>(MaterialPageRoute(builder: (_) => editor));
    if (!mounted) return;
    if (result != null && result.mealSaved) {
      Navigator.pop(context, result);
      return;
    }
    await _discardPhoto();
    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      setState(() => _phase = _Phase.choose);
    }
  }

  Future<void> _discardPhoto() async {
    final photo = _photo;
    _photo = null;
    if (photo != null) await _scope.photos.delete(photo);
  }

  void _manual() => _openEditor(MealEditorScreen(photoPath: _photo, openAddFood: true));

  @override
  Widget build(BuildContext context) {
    final analysis = _scope.analysis;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan a meal'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            await _discardPhoto();
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_phase) {
            _Phase.analyzing => _Analyzing(
              key: const ValueKey('analyzing'),
              photo: _scope.photos.resolve(_photo!),
              isDemo: analysis.isDemo,
            ),
            _Phase.failed => _Failed(
              key: const ValueKey('failed'),
              photo: _photo == null ? null : _scope.photos.resolve(_photo!),
              onRetry: _analyze,
              onManual: _manual,
            ),
            _Phase.choose => _Choose(
              key: const ValueKey('choose'),
              isDemo: analysis.isDemo,
              failure: _pickFailure,
              onPick: _pick,
              onManual: _manual,
            ),
          },
        ),
      ),
    );
  }
}

class _Choose extends StatelessWidget {
  const _Choose({
    super.key,
    required this.isDemo,
    required this.failure,
    required this.onPick,
    required this.onManual,
  });

  final bool isDemo;
  final PhotoPickFailed? failure;
  final ValueChanged<PhotoSource> onPick;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, NqSpace.page, NqSpace.xxl),
      children: [
        if (isDemo)
          const NoticeCard(
            icon: Icons.science_outlined,
            title: 'Demo analysis',
            message:
                'Food recognition isn’t connected yet, so you’ll get a sample meal to edit. '
                'Your photo stays on this phone and is never uploaded.',
          ),
        const SizedBox(height: NqSpace.xxxl),
        const Center(child: NutriqMark(size: 64)),
        const SizedBox(height: NqSpace.xl),
        const Text('Photograph your plate', style: NqText.title, textAlign: TextAlign.center),
        const SizedBox(height: NqSpace.sm),
        Text(
          'Good light and the whole plate in frame help. You’ll review and correct every food before anything is saved.',
          style: NqText.callout,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NqSpace.xxl),
        if (failure != null) ...[_failureCard(failure!), const SizedBox(height: NqSpace.lg)],
        PrimaryButton(
          label: 'Take photo',
          icon: Icons.photo_camera_outlined,
          onPressed: () => onPick(PhotoSource.camera),
        ),
        const SizedBox(height: NqSpace.md),
        SecondaryButton(
          label: 'Choose photo',
          icon: Icons.photo_library_outlined,
          onPressed: () => onPick(PhotoSource.library),
        ),
        const SizedBox(height: NqSpace.lg),
        Center(
          child: QuietButton(label: 'Enter manually', onPressed: onManual, color: NqColors.textSecondary),
        ),
      ],
    );
  }

  Widget _failureCard(PhotoPickFailed f) {
    final (title, message) = switch (f.failure) {
      PhotoFailure.permissionDenied when f.source == PhotoSource.camera => (
        'Camera access is off',
        'To scan meals, allow camera access in Settings → Nutriq. You can still choose a photo or enter the meal manually.',
      ),
      PhotoFailure.permissionDenied => (
        'Photo access is off',
        'Allow photo access in Settings → Nutriq, or take a new photo or enter the meal manually.',
      ),
      PhotoFailure.cameraUnavailable => (
        'No camera available',
        'This device has no usable camera. Choose a photo from your library instead.',
      ),
      PhotoFailure.unknown => (
        'Couldn’t open photos',
        'Something went wrong. Try again, or enter the meal manually.',
      ),
    };
    return NoticeCard(
      title: title,
      message: message,
      icon: Icons.no_photography_outlined,
      color: NqColors.coral,
    );
  }
}

class _Analyzing extends StatefulWidget {
  const _Analyzing({super.key, required this.photo, required this.isDemo});

  final File photo;
  final bool isDemo;

  @override
  State<_Analyzing> createState() => _AnalyzingState();
}

class _AnalyzingState extends State<_Analyzing> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.all(NqSpace.page),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NqRadius.card),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    widget.photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: NqColors.raised),
                  ),
                  ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
                  if (!reduceMotion)
                    AnimatedBuilder(
                      animation: _sweep,
                      builder: (context, _) => Align(
                        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_sweep.value)),
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: NqColors.sage,
                            boxShadow: [
                              BoxShadow(
                                color: NqColors.sage.withValues(alpha: 0.6),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: NqSpace.xl),
          if (reduceMotion) const LinearProgressIndicator(),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.isDemo ? 'Preparing a sample estimate…' : 'Estimating foods…',
              style: NqText.headline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isDemo
                ? 'Demo mode: results are samples. Your photo isn’t uploaded.'
                : 'This usually takes a few seconds.',
            style: NqText.footnote,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NqSpace.lg),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.photo, required this.onRetry, required this.onManual});

  final File? photo;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(NqSpace.page),
    children: [
      if (photo != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(NqRadius.card),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.file(
              photo!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: NqColors.raised),
            ),
          ),
        ),
      const SizedBox(height: NqSpace.xl),
      const NoticeCard(
        title: 'Couldn’t estimate this photo',
        message: 'The analysis didn’t finish. Try again, or enter the meal yourself — your photo will be kept with it.',
        icon: Icons.error_outline_rounded,
        color: NqColors.coral,
      ),
      const SizedBox(height: NqSpace.xl),
      PrimaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry),
      const SizedBox(height: NqSpace.md),
      SecondaryButton(label: 'Enter manually', icon: Icons.edit_note_rounded, onPressed: onManual),
    ],
  );
}
