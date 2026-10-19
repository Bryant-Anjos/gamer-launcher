import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

/// Título grande das seções, com subtítulo opcional.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final line = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (line != null) MutedText(line),
        ],
      ),
    );
  }
}

/// Mensagem de lista vazia.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Dimens.gutter),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: Dimens.gap),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
