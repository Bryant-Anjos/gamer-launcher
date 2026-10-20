import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

/// Título grande das seções, com subtítulo opcional.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.inset = Dimens.focusInset,
  });

  final String title;
  final String? subtitle;

  /// Alinha o título com o conteúdo, que rola com a folga do foco; numa
  /// página que já rola com essa folga (Configurações), zero.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final line = subtitle;
    return Padding(
      padding: EdgeInsets.only(left: inset, bottom: Dimens.gutter),
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
    padding: const EdgeInsets.fromLTRB(
      Dimens.focusInset,
      Dimens.gutter,
      0,
      Dimens.gutter,
    ),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: Dimens.gap),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
