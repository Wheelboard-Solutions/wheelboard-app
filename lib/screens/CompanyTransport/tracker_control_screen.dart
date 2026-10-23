import 'package:flutter/material.dart';

import '../../services/tracker_command_service.dart';

/// Fleet-owner controls for an iTriangle tracker linked to this vehicle.
class TrackerControlScreen extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;

  const TrackerControlScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  @override
  State<TrackerControlScreen> createState() => _TrackerControlScreenState();
}

class _TrackerControlScreenState extends State<TrackerControlScreen> {
  final _service = TrackerCommandService();
  Map<String, dynamic>? _status;
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _events = [];
  String? _error;
  String? _eventsError;
  bool _loading = true;
  bool _busy = false;

  bool get _online => _status?['connected'] == true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _eventsError = null;
    });
    try {
      final status = await _service.status(widget.vehicleId);
      if (!mounted) return;
      setState(() => _status = status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = null;
        _error = _errorText(e);
      });
    }
    try {
      final events = await _service.events(widget.vehicleId);
      if (!mounted) return;
      setState(() => _events = events);
    } catch (e) {
      if (!mounted) return;
      setState(() => _eventsError = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _notice(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _run(String action, {Map<String, int> values = const {}}) async {
    if (_busy || !_online) return;
    setState(() => _busy = true);
    try {
      final result = await _service.run(
        widget.vehicleId,
        action,
        ignitionOnSeconds: values['ignitionOnSeconds'],
        ignitionOffSeconds: values['ignitionOffSeconds'],
        speedKmh: values['speedKmh'],
      );
      if (!mounted) return;
      if (action == 'read_settings') {
        final entries = result['results'];
        if (entries is List) {
          setState(
            () => _settings = {
              for (final entry in entries.whereType<Map>())
                if (entry['key'] != null && entry['value'] != null)
                  entry['key'].toString(): entry['value'].toString(),
            },
          );
        }
      }
      _notice(
        action == 'read_settings'
            ? 'Tracker settings updated'
            : 'Tracker acknowledged the command',
      );
      await _refresh();
    } catch (e) {
      if (mounted) _notice(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndRun(
    String action,
    String title,
    String detail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send command'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _run(action);
  }

  Future<void> _setInterval() async {
    final values = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => const _TrackerNumberDialog(
        title: 'Reporting interval',
        fields: [
          _NumberField('Ignition on (seconds)', 'ignitionOnSeconds', 5, 3600),
          _NumberField(
            'Ignition off (seconds)',
            'ignitionOffSeconds',
            10,
            86400,
          ),
        ],
      ),
    );
    if (values != null && mounted) {
      await _run('set_reporting_interval', values: values);
    }
  }

  Future<void> _setOverspeed() async {
    final values = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => const _TrackerNumberDialog(
        title: 'Over-speed limit',
        fields: [_NumberField('Limit (km/h)', 'speedKmh', 20, 200)],
      ),
    );
    if (values != null && mounted) {
      await _run('set_overspeed_limit', values: values);
    }
  }

  Widget _setting(String label, String key, String unit) {
    final value = _settings[key];
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value == null ? '—' : '$value$unit'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final lastSeen = DateTime.tryParse(status?['lastSeen']?.toString() ?? '');
    final commandEnabled = _online && !_busy && !_loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Tracker controls')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.vehicleName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _online ? Icons.wifi : Icons.wifi_off,
                          color: _online ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _loading
                              ? 'Checking tracker…'
                              : _online
                              ? 'Online'
                              : 'Offline',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _loading ? null : _refresh,
                          tooltip: 'Refresh status',
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    if (lastSeen != null)
                      Text('Last seen: ${lastSeen.toLocal()}'),
                    if (status?['imei'] != null)
                      Text('IMEI: ${status!['imei']}'),
                    if (!_online && !_loading && _error == null)
                      const Text(
                        'Commands require the tracker to be connected.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Device commands',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_remote),
                    title: const Text('Read settings'),
                    subtitle: const Text('Fetch current device values'),
                    enabled: commandEnabled,
                    onTap: commandEnabled ? () => _run('read_settings') : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_open),
                    title: const Text('Mobilise'),
                    subtitle: const Text('Allow the vehicle to start'),
                    enabled: commandEnabled,
                    onTap: commandEnabled
                        ? () => _confirmAndRun(
                            'mobilize',
                            'Mobilise vehicle?',
                            'Send a command to allow this vehicle to start?',
                          )
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Immobilise'),
                    subtitle: const Text(
                      'Request safe immobilisation at low speed',
                    ),
                    enabled: commandEnabled,
                    onTap: commandEnabled
                        ? () => _confirmAndRun(
                            'immobilize',
                            'Immobilise vehicle?',
                            'The tracker will apply safe immobilisation when the vehicle slows down. Confirm the vehicle and driver situation before sending.',
                          )
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Reporting interval'),
                    enabled: commandEnabled,
                    onTap: commandEnabled ? _setInterval : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: const Text('Over-speed limit'),
                    enabled: commandEnabled,
                    onTap: commandEnabled ? _setOverspeed : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Restart tracker'),
                    enabled: commandEnabled,
                    onTap: commandEnabled
                        ? () => _confirmAndRun(
                            'restart',
                            'Restart tracker?',
                            'Tracking may pause briefly while the device restarts.',
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (_settings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Current settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Card(
                child: Column(
                  children: [
                    _setting('Ignition on interval', '130', ' s'),
                    _setting('Ignition off interval', '133', ' s'),
                    _setting('Over-speed limit', '150', ' km/h'),
                    _setting('Immobiliser', '176', ''),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Recent tracker events',
                style: Theme.of(context).textTheme.titleMedium),
            if (_eventsError != null)
              Text(_eventsError!, style: const TextStyle(color: Colors.red)),
            Card(
              child: _events.isEmpty
                  ? const ListTile(title: Text('No events recorded yet'))
                  : Column(children: [
                      for (final event in _events)
                        ListTile(
                          leading: Icon(
                            event['eventType'] == 'accident' ||
                                    event['eventType'] == 'emergency_sos' ||
                                    event['eventType'] == 'panic_button'
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_outlined,
                          ),
                          title: Text(event['title']?.toString() ??
                              event['eventType']?.toString() ?? 'Tracker event'),
                          subtitle: Text(DateTime.tryParse(
                                      event['recordedAt']?.toString() ?? '')
                                  ?.toLocal()
                                  .toString() ??
                              ''),
                        ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField {
  final String label;
  final String key;
  final int min;
  final int max;
  const _NumberField(this.label, this.key, this.min, this.max);
}

class _TrackerNumberDialog extends StatefulWidget {
  final String title;
  final List<_NumberField> fields;
  const _TrackerNumberDialog({required this.title, required this.fields});

  @override
  State<_TrackerNumberDialog> createState() => _TrackerNumberDialogState();
}

class _TrackerNumberDialogState extends State<_TrackerNumberDialog> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = [
    for (final _ in widget.fields) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.fields.length; i++)
            TextFormField(
              controller: _controllers[i],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.fields[i].label,
                helperText: '${widget.fields[i].min}–${widget.fields[i].max}',
              ),
              validator: (raw) {
                final value = int.tryParse(raw?.trim() ?? '');
                final field = widget.fields[i];
                if (value == null || value < field.min || value > field.max) {
                  return 'Enter ${field.min}–${field.max}';
                }
                return null;
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, {
            for (var i = 0; i < widget.fields.length; i++)
              widget.fields[i].key: int.parse(_controllers[i].text.trim()),
          });
        },
        child: const Text('Send command'),
      ),
    ],
  );
}
