import 'package:flutter/widgets.dart';
import 'package:gamer_launcher/state/poller.dart';

/// Mantém as leituras ligadas só enquanto este pedaço da tela existir.
class PollerAttachment extends StatefulWidget {
  const PollerAttachment({
    super.key,
    required this.pollers,
    required this.child,
  });

  final List<Poller> pollers;
  final Widget child;

  @override
  State<PollerAttachment> createState() => _PollerAttachmentState();
}

class _PollerAttachmentState extends State<PollerAttachment> {
  @override
  void initState() {
    super.initState();
    for (final poller in widget.pollers) {
      poller.attach();
    }
  }

  @override
  void dispose() {
    for (final poller in widget.pollers) {
      poller.detach();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
