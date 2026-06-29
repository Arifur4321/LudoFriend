import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';

class _Rule {
  const _Rule(this.title, this.body);
  final String title;
  final String body;
}

class HelpRulesScreen extends StatelessWidget {
  const HelpRulesScreen({super.key});

  static const _rules = [
    _Rule('Goal',
        'Be the first to bring all four of your tokens around the board and into your home.'),
    _Rule('Leaving base',
        'You must roll a 6 to move a token out of its base onto its start cell.'),
    _Rule('Rolling a six',
        'A 6 earns you another roll. But roll three 6s in a row and your turn is skipped!'),
    _Rule('Capturing',
        'Land exactly on an opponent and you send their token back to base — unless they are on a safe star cell.'),
    _Rule('Safe cells',
        'The colored start cells and star cells are safe. Tokens resting there cannot be captured.'),
    _Rule('Reaching home',
        'Travel the full lap, then up your colored home column. You must land exactly on the final home cell.'),
    _Rule('Winning',
        'The first player to get all four tokens home wins the match. Captures and reaching home grant a bonus roll.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            itemCount: _rules.length,
            itemBuilder: (context, i) {
              final r = _rules[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: Text('${i + 1}',
                              style:
                                  AppTextStyles.button.copyWith(fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        Text(r.title, style: AppTextStyles.title),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r.body, style: AppTextStyles.body),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
