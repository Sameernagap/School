import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

/// Diary values shared by the parent and teacher screens.
const moodEmoji = {
  'happy': '😊',
  'okay': '🙂',
  'quiet': '😶',
  'tired': '😴',
  'upset': '😢',
};

const moodLabels = {
  'happy': 'Happy',
  'okay': 'Okay',
  'quiet': 'Quiet',
  'tired': 'Tired',
  'upset': 'Upset',
};

const mealLabels = {
  'all': 'Ate all',
  'most': 'Ate most',
  'half': 'Ate half',
  'little': 'Ate a little',
  'none': 'Did not eat',
};

const napLabels = {
  'slept': 'Slept well',
  'rested': 'Rested',
  'no': 'No nap',
};

/// Colour of a meal value: green when the child ate well, amber / red otherwise.
Color mealColor(String? value) {
  switch (value) {
    case 'all':
    case 'most':
      return AppColors.emerald;
    case 'half':
      return AppColors.amber;
    case 'little':
    case 'none':
      return AppColors.rose;
  }
  return AppColors.muted;
}

/// Whether the daily diary is shown for this child (pre-primary school, or a pre-primary class).
bool diaryForStudent(AppState state, Map<String, dynamic>? student) {
  if (!state.hasFeature('diary') || student == null) return false;
  return state.school['type'] == 'preprimary' || student['preprimary'] == true;
}

/// Image from the school server (sends the sign-in token).
class ServerImage extends StatelessWidget {
  const ServerImage({super.key, required this.path, this.fit = BoxFit.cover, this.width, this.height});

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Image.network(
      api.url(path),
      headers: api.authHeaders,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              width: width,
              height: height,
              color: AppColors.soft(AppColors.indigo),
              alignment: Alignment.center,
              child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: AppColors.soft(AppColors.slate),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded, color: AppColors.muted),
      ),
    );
  }
}

/// Round tinted chip used for meal / nap / mood choices.
class ChoicePill extends StatelessWidget {
  const ChoicePill(
      {super.key, required this.label, required this.selected, required this.color, required this.onTap, this.emoji});

  final String label;
  final String? emoji;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : AppColors.line, width: 1.5),
          ),
          child: Text(
            emoji == null ? label : '$emoji $label',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
