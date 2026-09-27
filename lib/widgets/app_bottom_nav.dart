import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';


/// Shared animated bottom navigation bar.
///
/// Uses Iconsax icons with a pill indicator that slides to the active tab.
/// Both [CompanyTransportMainWrapper] and [ProfessionalMainWrapper] use this.
class AppBottomNav extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor = const Color(0xFFF36969),
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 64 + bottomPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            return Expanded(
              child: _NavTab(
                item: items[i],
                isActive: i == currentIndex,
                activeColor: activeColor,
                onTap: () => onTap(i),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Single tab with animated icon scale + color + pill indicator.
class _NavTab extends StatefulWidget {
  final AppNavItem item;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavTab({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    if (widget.isActive) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavTab old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.forward();
    } else if (!widget.isActive && old.isActive) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final color = widget.isActive
              ? widget.activeColor
              : const Color(0xFF9CA3AF);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: _scale.value,
                child: Icon(
                  widget.isActive ? widget.item.activeIcon : widget.item.icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.label.tr,
                style: TextStyle(

                  fontSize: 10,
                  fontWeight: widget.isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: color,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 2),
              // Active pill indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: widget.isActive ? 24 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: widget.activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Data class for a nav tab item.
class AppNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const AppNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// ── Pre-built item sets ──────────────────────────────────────────────────────

/// Nav items for Company / Transport role.
const companyNavItems = [
  AppNavItem(
    label: 'Home',
    icon: Iconsax.home,
    activeIcon: Iconsax.home_2,
  ),
  AppNavItem(
    label: 'Fleet',
    icon: Iconsax.truck,
    activeIcon: Iconsax.truck_tick,
  ),
  AppNavItem(
    label: 'Trips',
    icon: Iconsax.routing,
    activeIcon: Iconsax.routing_2,
  ),
  AppNavItem(
    label: 'Feeds',
    icon: Iconsax.document_text,
    activeIcon: Iconsax.document_text_1,
  ),
  AppNavItem(
    label: 'Jobs',
    icon: Iconsax.briefcase,
    activeIcon: Iconsax.briefcase1,
  ),
];

/// Nav items for Professional / Driver role.
const professionalNavItems = [
  AppNavItem(
    label: 'Home',
    icon: Iconsax.home,
    activeIcon: Iconsax.home_2,
  ),
  AppNavItem(
    label: 'Find',
    icon: Iconsax.search_normal,
    activeIcon: Iconsax.search_normal_1,
  ),
  AppNavItem(
    label: 'Trips',
    icon: Iconsax.routing,
    activeIcon: Iconsax.routing_2,
  ),
  AppNavItem(
    label: 'Feeds',
    icon: Iconsax.document_text,
    activeIcon: Iconsax.document_text_1,
  ),
  AppNavItem(
    label: 'Jobs',
    icon: Iconsax.briefcase,
    activeIcon: Iconsax.briefcase1,
  ),
];
