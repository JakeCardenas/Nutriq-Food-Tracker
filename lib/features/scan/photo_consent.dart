import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../state/photo_analysis_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';

/// Asks before the first upload. Returns true (send photos), false (keep them
/// on the phone) or null (dismissed — nothing is sent, and it asks again next time).
Future<bool?> askPhotoEstimateConsent(BuildContext context, {required bool onDeviceAvailable}) => showNqSheet<bool>(
  context,
  title: 'Get a photo estimate?',
  child: _ConsentBody(onDeviceAvailable: onDeviceAvailable),
);

/// Before a photo is analysed: asks once per account on this phone.
Future<void> askPhotoEstimateConsentIfNeeded(BuildContext context, PhotoAnalysisController photos) async {
  if (!photos.needsCloudChoice) return;
  final answer = await askPhotoEstimateConsent(context, onDeviceAvailable: photos.onDevice.recognizesPhotos);
  if (answer != null) await photos.setCloudEnabled(answer);
}

/// Settings switch: turning on asks first; turning off doesn't.
Future<void> setPhotoEstimatesFromSettings(BuildContext context, PhotoAnalysisController photos, bool on) async {
  if (!on) return photos.setCloudEnabled(false);
  final answer = await askPhotoEstimateConsent(context, onDeviceAvailable: photos.onDevice.recognizesPhotos);
  if (answer == true) await photos.setCloudEnabled(true);
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody({required this.onDeviceAvailable});

  final bool onDeviceAvailable;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Nutriq can send this photo to Google’s Gemini AI to identify the foods and portion sizes; calories and '
        'protein then come from food data, not from the AI. The photo leaves your phone — a smaller copy without '
        'location or camera details, via Nutriq’s server.',
        style: NqText.callout.copyWith(color: NqColors.ink),
      ),
      const SizedBox(height: NqSpace.md),
      for (final point in const [
        'It uses Gemini’s free tier: Google’s terms let it use what’s sent to improve its products, and people at '
            'Google may review it. Don’t send private photos.',
        'Nutriq’s server doesn’t keep the photo. Estimates can be wrong — you check every food and amount before '
            'logging.',
        'There’s a daily limit. Turn this off any time in Settings.',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: NqText.footnote),
              Expanded(child: Text(point, style: NqText.footnote)),
            ],
          ),
        ),
      const SizedBox(height: NqSpace.md),
      PrimaryButton(label: 'Send photos for estimates', onPressed: () => Navigator.pop(context, true)),
      const SizedBox(height: 10),
      SecondaryButton(label: 'Keep photos on this phone', onPressed: () => Navigator.pop(context, false)),
      const SizedBox(height: 6),
      Text(
        onDeviceAvailable ? 'You’ll still get on-device suggestions.' : 'You’ll describe your meals instead.',
        style: NqText.caption,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
