/// Reusable list card mirroring `components/shared/ItemCard.vue`. Shows
/// title (e.g. id), subtitle (type/provider), status chip, an enable/disable
/// switch and a tap handler. Edit / delete are exposed via a popup menu.
library;

import 'package:flutter/material.dart';

class ItemCardAction {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
  ItemCardAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.statusLabel,
    this.statusColor,
    this.enabled,
    this.onEnabledChanged,
    this.onTap,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? statusLabel;
  final Color? statusColor;
  final bool? enabled;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onTap;
  final List<ItemCardAction> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(icon ?? Icons.category_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (statusColor ?? cs.outline)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: statusColor ?? cs.outline),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (enabled != null)
                Switch(
                  value: enabled!,
                  onChanged: onEnabledChanged,
                ),
              if (actions.isNotEmpty)
                PopupMenuButton<int>(
                  itemBuilder: (_) => [
                    for (var i = 0; i < actions.length; i++)
                      PopupMenuItem(
                        value: i,
                        child: Row(
                          children: [
                            Icon(
                              actions[i].icon,
                              size: 18,
                              color: actions[i].destructive ? cs.error : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              actions[i].label,
                              style: TextStyle(
                                color:
                                    actions[i].destructive ? cs.error : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (i) => actions[i].onSelected(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
