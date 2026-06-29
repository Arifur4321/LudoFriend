import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';

class _Slide {
  const _Slide(this.asset, this.title, this.body);
  final String asset;
  final String title;
  final String body;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(AppAssets.illusEmpty, 'Roll & Race',
        'Classic Ludo fun with smooth animations and a fresh, friendly look.'),
    _Slide(AppAssets.illusEmpty, 'Play Together',
        'Pass-and-play on one phone, challenge bots, or battle friends online.'),
    _Slide(AppAssets.illusEmpty, 'Make it Yours',
        'Guest play, accounts, rooms and leaderboards — your call.'),
  ];

  Future<void> _finish() async {
    await ref.read(prefsProvider).setOnboardingDone(true);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child:
                      const Text('Skip', style: TextStyle(color: Colors.white)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _slides.length,
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(s.asset, height: 220),
                          const SizedBox(height: 36),
                          Text(s.title,
                              style: AppTextStyles.display,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          Text(s.body,
                              style: AppTextStyles.body
                                  .copyWith(color: Colors.white70),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(4),
                    width: _page == i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: _page == i ? 1 : 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(
                  label: last ? 'Get Started' : 'Next',
                  onPressed: () {
                    if (last) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
