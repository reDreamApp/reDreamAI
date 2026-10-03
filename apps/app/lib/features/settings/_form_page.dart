import 'package:flutter/material.dart';

import 'package:redream_app/core/widgets/app_card.dart';

/// Shared scaffold for the small account forms: icon, heading, body, fields.
class FormPage extends StatelessWidget {
  const FormPage({
    required this.title,
    required this.icon,
    required this.heading,
    required this.body,
    required this.children,
    super.key,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final String heading;
  final String body;
  final List<Widget> children;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                size: 48,
                color: iconColor ?? theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
