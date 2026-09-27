import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wheelbot_message.dart';
import '../services/wheelbot_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.wheelboard.app&pcampaignid=web_share';

const _welcome =
    'Welcome to Wheelboard Solutions! We are building a transport ecosystem grounded in empowerment, driven by efficiency, and united by shared success. How would you like to use Wheelboard today?';

const _userTypeActions = [
  WheelbotAction(label: 'Transport Company', action: 'company', icon: '🚚'),
  WheelbotAction(label: 'Professional', action: 'professional', icon: '🧑‍🔧'),
  WheelbotAction(
    label: 'Service Provider',
    action: 'service_provider',
    icon: '🏪',
  ),
  WheelbotAction(label: 'Learn / Contact', action: 'learn_contact', icon: 'ℹ️'),
];

const _companyActions = [
  WheelbotAction(
    label: 'Fleet Operations',
    action: 'fleet_operations',
    icon: '🚛',
  ),
  WheelbotAction(label: 'Driver Network', action: 'driver_network', icon: '👥'),
  WheelbotAction(
    label: 'Digital Backbone',
    action: 'digital_backbone',
    icon: '📊',
  ),
];

const _professionalActions = [
  WheelbotAction(label: 'Verified Jobs', action: 'verified_jobs', icon: '✅'),
  WheelbotAction(
    label: 'Better Earnings',
    action: 'better_earnings',
    icon: '💰',
  ),
  WheelbotAction(label: 'Skill Growth', action: 'skill_growth', icon: '📚'),
];

const _serviceProviderActions = [
  WheelbotAction(
    label: 'Get Verified Leads',
    action: 'verified_leads',
    icon: '📈',
  ),
  WheelbotAction(label: 'Service Radius', action: 'service_radius', icon: '📍'),
  WheelbotAction(label: 'Grow Revenue', action: 'grow_revenue', icon: '🤝'),
];

const _generalActions = [
  WheelbotAction(label: 'How it works', action: 'how_it_works', icon: '❓'),
  WheelbotAction(
    label: 'Subscription Plans',
    action: 'subscription_plans',
    icon: '💳',
  ),
  WheelbotAction(label: 'wheelboard.in', action: 'visit_website', icon: '🌐'),
  WheelbotAction(label: 'Download App', action: 'download_app', icon: '📱'),
  WheelbotAction(
    label: 'Contact Support',
    action: 'contact_support',
    icon: '📧',
  ),
  WheelbotAction(label: 'Restart Menu', action: 'restart', icon: '🔄'),
];

class WheelbotFloatingButton extends StatelessWidget {
  final String roleContext;
  final double bottom;
  final double right;

  const WheelbotFloatingButton({
    super.key,
    required this.roleContext,
    this.bottom = 86,
    this.right = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom + MediaQuery.of(context).padding.bottom,
      child: Semantics(
        button: true,
        label: 'Open WheelBot assistant',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => WheelbotSheet.show(context, roleContext: roleContext),
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppPalette.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WheelbotSheet extends StatefulWidget {
  final String roleContext;

  const WheelbotSheet({super.key, required this.roleContext});

  static Future<void> show(
    BuildContext context, {
    required String roleContext,
  }) {
    return Get.bottomSheet<void>(
      WheelbotSheet(roleContext: roleContext),
      isScrollControlled: true,
      ignoreSafeArea: false,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<WheelbotSheet> createState() => _WheelbotSheetState();
}

class _WheelbotSheetState extends State<WheelbotSheet> {
  final _service = const WheelbotService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late List<WheelbotMessage> _messages;
  String _context = 'userType';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _context = widget.roleContext;
    _messages = [
      WheelbotMessage(
        role: 'assistant',
        content: _welcome,
        timestamp: DateTime.now(),
        buttons: _buttonsForContext(_context),
      ),
    ];
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    final userMessage = WheelbotMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _input.clear();
      _loading = true;
    });
    _scrollToEnd();

    final reply = await _service.send(messages: _messages);
    if (!mounted) return;

    setState(() {
      _messages.add(
        WheelbotMessage(
          role: 'assistant',
          content: reply.success
              ? (reply.message ??
                    'I am here to help. What would you like to do next?')
              : (reply.error ?? 'WheelBot could not respond right now.'),
          timestamp: DateTime.now(),
          buttons: _buttonsForContext(_context),
        ),
      );
      _loading = false;
    });
    _scrollToEnd();
  }

  Future<void> _handleAction(WheelbotAction action) async {
    if (_loading) return;

    final currentContext = _context;
    final nextContext = _contextForAction(action.action, currentContext);
    setState(() {
      _messages.add(
        WheelbotMessage(
          role: 'user',
          content: '${action.icon} ${action.label}',
          timestamp: DateTime.now(),
        ),
      );
      _context = nextContext;
      _loading = true;
    });
    _scrollToEnd();

    final reply = await _service.send(messages: _messages);
    if (!mounted) return;

    setState(() {
      _messages.add(
        WheelbotMessage(
          role: 'assistant',
          content: reply.success
              ? (reply.message ??
                    'I am here to help. What would you like to do next?')
              : (reply.error ?? 'WheelBot could not respond right now.'),
          timestamp: DateTime.now(),
          buttons: _buttonsForAction(action.action),
        ),
      );
      _loading = false;
    });
    _scrollToEnd();
    _runSideEffect(action.action);
  }

  void _clear() {
    setState(() {
      _context = widget.roleContext;
      _messages = [
        WheelbotMessage(
          role: 'assistant',
          content: _welcome,
          timestamp: DateTime.now(),
          buttons: _buttonsForContext(_context),
        ),
      ];
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _runSideEffect(String action) {
    if (action == 'visit_website') {
      _launchExternal(Uri.parse('https://www.wheelboard.in'));
    }
    if (action == 'download_app') {
      _launchExternal(Uri.parse(_playStoreUrl));
    }
    if (action == 'contact_support') {
      _launchExternal(
        Uri(
          scheme: 'mailto',
          path: 'hello@wheelboard.in',
          queryParameters: const {'subject': 'Wheelboard Support'},
        ),
      );
    }
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        Get.snackbar('WheelBot', 'Could not open ${uri.toString()}');
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar('WheelBot', 'Could not open ${uri.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get.bottomSheet() already wraps its content in
    // Padding(bottom: viewInsets.bottom) at the route level (see
    // GetModalBottomSheetRoute.buildPage in the `get` package), so the
    // keyboard is already accounted for by the time this builds. Requesting
    // a fixed height here and letting Flutter's constraint clamping shrink it
    // when space is limited avoids double-compensating for the keyboard,
    // which was the cause of the leftover gap.
    final sheetHeight = MediaQuery.of(context).size.height * 0.86;
    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: AppPalette.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _Header(onClear: _clear),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_loading && index == _messages.length) {
                    return const _TypingBubble();
                  }
                  final message = _messages[index];
                  return _MessageBubble(
                    message: message,
                    onAction: _handleAction,
                  );
                },
              ),
            ),
            _Composer(
              controller: _input,
              loading: _loading,
              onSend: _sendText,
            ),
          ],
        ),
      ),
    );
  }

  List<WheelbotAction> _buttonsForContext(String context) {
    return switch (context) {
      'company' => [..._companyActions, ..._generalActions],
      'professional' => [..._professionalActions, ..._generalActions],
      'serviceProvider' => [..._serviceProviderActions, ..._generalActions],
      _ => [..._userTypeActions, ..._generalActions],
    };
  }

  List<WheelbotAction> _buttonsForAction(String action) {
    if (action == 'company') return [..._companyActions, ..._generalActions];
    if (action == 'professional') {
      return [..._professionalActions, ..._generalActions];
    }
    if (action == 'service_provider') {
      return [..._serviceProviderActions, ..._generalActions];
    }
    if (action == 'restart') return _userTypeActions;
    return _generalActions;
  }

  String _contextForAction(String action, String current) {
    if (action == 'company') return 'company';
    if (action == 'professional') return 'professional';
    if (action == 'service_provider') return 'serviceProvider';
    if (action == 'restart') return 'userType';
    return current;
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClear;

  const _Header({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 14),
      decoration: const BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppPalette.border,
              borderRadius: AppRadius.rPill,
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppPalette.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WheelBot AI Assistant', style: AppText.h3),
                    Text(
                      'Wheelboard knowledge + AI assistance',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear chat',
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: Get.back,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final WheelbotMessage message;
  final ValueChanged<WheelbotAction> onAction;

  const _MessageBubble({required this.message, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) const _Avatar(icon: Icons.smart_toy_rounded),
              if (!isUser) AppSpacing.hGapSm,
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser ? AppPalette.brandGradient : null,
                    color: isUser ? null : AppPalette.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: AppText.bodySm.on(
                      isUser ? Colors.white : AppPalette.textMid,
                    ),
                  ),
                ),
              ),
              if (isUser) AppSpacing.hGapSm,
              if (isUser) const _Avatar(icon: Icons.person_rounded, dark: true),
            ],
          ),
          if (!isUser && message.buttons.isNotEmpty) ...[
            AppSpacing.vGapSm,
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.buttons.map((button) {
                  return ActionChip(
                    label: Text('${button.icon} ${button.label}'),
                    labelStyle: AppText.label.on(AppPalette.textMid),
                    backgroundColor: AppPalette.card,
                    side: const BorderSide(color: Color(0xFFFFD4D4)),
                    shape: const StadiumBorder(),
                    onPressed: () => onAction(button),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final IconData icon;
  final bool dark;

  const _Avatar({required this.icon, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: dark ? AppPalette.textMid : AppPalette.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _Avatar(icon: Icons.smart_toy_rounded),
          SizedBox(width: 8),
          _TypingDots(),
        ],
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: AppRadius.rXl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Container(
            width: 7,
            height: 7,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 5),
            decoration: const BoxDecoration(
              color: AppPalette.primary,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.card,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!loading) onSend();
                  },
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: AppText.bodySm.on(AppPalette.textFaint),
                    filled: true,
                    fillColor: AppPalette.bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.rXl,
                      borderSide: const BorderSide(color: AppPalette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.rXl,
                      borderSide: const BorderSide(color: AppPalette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.rXl,
                      borderSide: const BorderSide(color: AppPalette.primary),
                    ),
                  ),
                ),
              ),
              AppSpacing.hGapSm,
              SizedBox(
                height: 48,
                width: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppPalette.brandGradient,
                    borderRadius: AppRadius.rLg,
                  ),
                  child: IconButton(
                    onPressed: loading ? null : onSend,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vGapSm,
          Text(
            'WheelBot can make mistakes. Please verify important information.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
