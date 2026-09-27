import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/Transport/service_provider_controller.dart';
import '../../controllers/Transport/user_profile_controller.dart';
import '../../core/auth/auth_service.dart';
import '../../models/service_model.dart';
import '../../models/service_payload.dart';
import '../../theme/design_system.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import '../../utils/placeservices.dart';
import '../../widgets/custom_snackbar.dart';

/// Create / edit a service listing. Mirrors the wheelboard-fe `AddServiceModal`
/// flow and submits the web's JSON contract via [ServiceProviderController]
/// (`ServicePayload` → `CreateServiceDto`). Free-tier providers transparently
/// run the one-time listing-fee Razorpay flow inside the controller.
class AddServiceScreen extends StatefulWidget {
  /// When provided, the screen is in edit mode.
  final ServiceModel? service;

  const AddServiceScreen({super.key, this.service});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ServiceProviderController _controller;

  final _titleCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  int _descLen = 0;

  // 'Fixed' | 'Hourly' | 'On Request' — same set as the web pricing options.
  String _pricingType = 'Fixed';

  // Multiple category selection. (The web is single-select; the app allows
  // multi-select per spec — selections are joined into the backend `category`
  // string and mirrored into `tags[]` so the single-string contract is kept.)
  final Set<String> _selectedCategories = <String>{};

  // Full day names (Monday…Sunday) — what the backend `availability.days` holds.
  static const _dayOptions = <(String, String)>[
    ('Mon', 'Monday'),
    ('Tue', 'Tuesday'),
    ('Wed', 'Wednesday'),
    ('Thu', 'Thursday'),
    ('Fri', 'Friday'),
    ('Sat', 'Saturday'),
    ('Sun', 'Sunday'),
  ];
  final Set<String> _selectedDays = {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  };

  String _from = '09:00';
  String _to = '18:00';
  bool _isVisible = true;

  // Existing (stored) image URLs kept on edit, plus newly picked files.
  final List<String> _existingImages = [];
  final List<File> _newImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  final PlacesService _places =
      PlacesService(apiKey: MapsConstants.googleMapsApiKey);
  List<Suggestion> _suggestions = [];

  /// Coordinates of the picked business address.
  ///
  /// Resolved by the same `PlacesService.fetchPlaceLocation` call the Transport
  /// new-trip screen makes after a pickup/delivery suggestion is tapped, so a
  /// service listing is located exactly the way a trip endpoint is.
  double? _latitude;
  double? _longitude;

  /// True while the Place Details lookup for the tapped suggestion is in
  /// flight, so Save can wait rather than persisting the address without its
  /// coordinates.
  bool _resolvingLocation = false;

  /// The in-flight Place Details lookup, awaited by Save so a listing is never
  /// written with the address but without its coordinates.
  Future<void>? _pendingLocationLookup;

  bool get _hasCoordinates => _latitude != null && _longitude != null;

  /// Manual address / coordinate entry, for the cases the Places search cannot
  /// serve: a workshop on an unmapped road, a yard Google pins in the wrong
  /// place, a provider who already knows their exact coordinates, or Places
  /// being unavailable at all (no API key, offline, quota).
  ///
  /// A separate mode rather than extra always-visible fields: with both a
  /// resolved place AND typed coordinates on screen there is no way to tell
  /// which one the listing is saved with. Exactly one is live at a time.
  bool _manualLocation = false;
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  // Canonical category options (per the design spec).
  List<String> _categoryOptions = const [
    'Brake Service',
    'Oil Change',
    'AC Repair',
    'Vehicle Service',
    'Tyre Service',
    'Others',
  ];

  bool get _isEdit => widget.service != null;
  int get _imageCount => _existingImages.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(ServiceProviderController(), permanent: false);

    // Categories come from the provider's profile `servicesOffered` when set,
    // otherwise fall back to the canonical four.
    // Merge any provider-offered categories into the canonical list (dedup) so
    // existing providers still see their custom categories as options.
    final profile = Get.put(UserProfileController()).userProfile.value;
    final offered = profile?.servicesOffered;
    if (offered != null && offered.trim().isNotEmpty) {
      final parsed = offered
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      final merged = <String>[..._categoryOptions];
      for (final c in parsed) {
        if (!merged.contains(c)) merged.add(c);
      }
      _categoryOptions = merged;
    }

    _descriptionCtrl.addListener(
        () => setState(() => _descLen = _descriptionCtrl.text.length));

    if (_isEdit) _populateForEdit();
  }

  void _populateForEdit() {
    final s = widget.service!;
    _titleCtrl.text = s.serviceTitle;
    _contactCtrl.text = s.contactNumber ?? '';
    _whatsappCtrl.text = s.whatsappNumber ?? '';
    _descriptionCtrl.text = s.description ?? '';
    _priceCtrl.text = s.amount?.toString() ?? '';
    _cityCtrl.text = s.city;
    _addressCtrl.text = s.fullAddress;
    // Keep the existing pin so re-saving an unchanged address does not drop it.
    // Null for listings created before the address was resolvable.
    _latitude = s.latitude;
    _longitude = s.longitude;
    _latCtrl.text = s.latitude?.toString() ?? '';
    _lngCtrl.text = s.longitude?.toString() ?? '';
    // A listing that has an address but no pin was either typed in by hand or
    // predates the Places flow — there is no place to restore. Open it in the
    // mode it was saved in; anything else opens in Places mode.
    _manualLocation = s.fullAddress.trim().isNotEmpty && !_hasCoordinates;
    _descLen = _descriptionCtrl.text.length;

    // Pricing type — normalize legacy values to the web set.
    final pt = (s.pricingOption ?? '').toLowerCase();
    if (pt.contains('hour')) {
      _pricingType = 'Hourly';
    } else if (pt.contains('request') || pt.contains('quote')) {
      _pricingType = 'On Request';
    } else {
      _pricingType = 'Fixed';
    }

    // Category — the stored value may be a comma-joined list (multi-select).
    final storedCats = (s.serviceCategory ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    for (final c in storedCats) {
      if (!_categoryOptions.contains(c)) {
        _categoryOptions = [..._categoryOptions, c];
      }
      _selectedCategories.add(c);
    }

    _isVisible = s.isAvailable;

    if (s.daysOpen != null && s.daysOpen!.trim().isNotEmpty) {
      _selectedDays
        ..clear()
        ..addAll(s.daysOpen!
            .split(',')
            .map((e) => _normalizeDay(e.trim()))
            .where((e) => e.isNotEmpty));
    }
    if (s.businessHoursFrom != null && s.businessHoursFrom!.isNotEmpty) {
      _from = s.businessHoursFrom!;
    }
    if (s.businessHoursTo != null && s.businessHoursTo!.isNotEmpty) {
      _to = s.businessHoursTo!;
    }

    _existingImages.addAll(s.images);
  }

  String _normalizeDay(String value) {
    final v = value.toLowerCase();
    for (final (short, full) in _dayOptions) {
      if (v == short.toLowerCase() || v == full.toLowerCase()) return full;
    }
    return value; // unknown → keep as-is
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contactCtrl.dispose();
    _whatsappCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _detailsCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.card,
        surfaceTintColor: AppPalette.card,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: AppPalette.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(_isEdit ? 'Edit Service' : 'Add New Service',
            style: AppText.h3),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
          children: [
            _FadeInUp(index: 0, child: _detailsSection()),
            AppSpacing.vGapLg,
            _FadeInUp(index: 1, child: _pricingSection()),
            AppSpacing.vGapLg,
            _FadeInUp(index: 2, child: _hoursSection()),
            AppSpacing.vGapLg,
            _FadeInUp(index: 3, child: _locationSection()),
            AppSpacing.vGapLg,
            _FadeInUp(index: 4, child: _gallerySection()),
            AppSpacing.vGapLg,
            _FadeInUp(index: 5, child: _visibilitySection()),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _sectionCard({required String title, IconData? icon, required List<Widget> children}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppPalette.primary),
                AppSpacing.hGapSm,
              ],
              Text(title, style: AppText.title),
            ]),
            AppSpacing.vGapLg,
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _detailsSection() {
    return _sectionCard(
      title: 'Service Details',
      icon: Iconsax.box,
      children: [
        _field(
          label: 'Service Title *',
          controller: _titleCtrl,
          hint: 'e.g., Professional Tyre Repair',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Service title is required' : null,
        ),
        AppSpacing.vGapLg,
        _categoryMultiSelect(),
        AppSpacing.vGapLg,
        _field(
          label: 'Contact Number *',
          controller: _contactCtrl,
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          prefixIcon: Iconsax.call,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Contact number is required';
            if (v.trim().length < 10) return 'Enter a valid contact number';
            return null;
          },
        ),
        AppSpacing.vGapLg,
        _field(
          label: 'WhatsApp Number (optional)',
          controller: _whatsappCtrl,
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          prefixIcon: Iconsax.message,
        ),
        AppSpacing.vGapLg,
        _field(
          label: 'Description *',
          controller: _descriptionCtrl,
          hint: 'Brief description of your service',
          maxLines: 4,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Description is required';
            if (v.length > 500) return 'Description cannot exceed 500 characters';
            return null;
          },
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text('$_descLen/500',
              style: AppText.caption
                  .on(_descLen > 500 ? AppPalette.danger : AppPalette.textFaint)),
        ),
      ],
    );
  }

  Widget _pricingSection() {
    final showAmount = _pricingType != 'On Request';
    return _sectionCard(
      title: 'Pricing',
      icon: Iconsax.money_4,
      children: [
        Row(
          children: [
            _pricingChip('Fixed', 'Fixed Price'),
            AppSpacing.hGapSm,
            _pricingChip('On Request', 'On Request'),
            AppSpacing.hGapSm,
            _pricingChip('Hourly', 'Hourly'),
          ],
        ),
        if (showAmount) ...[
          AppSpacing.vGapLg,
          _field(
            label: _pricingType == 'Hourly' ? 'Rate / hour *' : 'Amount *',
            controller: _priceCtrl,
            hint: '2500',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Iconsax.money,
            validator: (v) {
              if (!showAmount) return null;
              if (v == null || v.trim().isEmpty) return 'Amount is required';
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
        ],
        AppSpacing.vGapLg,
        _field(
          label: 'Pricing Note (optional)',
          controller: _detailsCtrl,
          hint: 'e.g., per tyre, inclusive of taxes',
        ),
      ],
    );
  }

  Widget _hoursSection() {
    return _sectionCard(
      title: 'Business Hours',
      icon: Iconsax.clock,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _dayOptions.map((d) => _dayChip(d.$1, d.$2)).toList(),
        ),
        AppSpacing.vGapLg,
        Row(
          children: [
            Expanded(child: _timeField('Start Time', _from, true)),
            AppSpacing.hGapMd,
            Expanded(child: _timeField('End Time', _to, false)),
          ],
        ),
      ],
    );
  }

  /// Accept a Places suggestion and resolve it to coordinates.
  ///
  /// Identical two-step flow to the Transport new-trip screen: fill the field
  /// from the prediction immediately so the UI never stalls, then look the
  /// place up via `fetchPlaceLocation(placeId)` for the exact lat/lng. The
  /// address is kept either way — only the pin is lost if the lookup fails.
  void _selectSuggestion(Suggestion s) {
    FocusScope.of(context).unfocus();
    setState(() {
      _addressCtrl.text = s.description;
      if (s.city.isNotEmpty) _cityCtrl.text = s.city;
      _suggestions = [];
      _latitude = null;
      _longitude = null;
      _resolvingLocation = true;
    });
    // Held so Save can await exactly this lookup instead of racing it.
    _pendingLocationLookup = _resolvePlace(s.placeId);
  }

  Future<void> _resolvePlace(String placeId) async {
    try {
      final loc = await _places.fetchPlaceLocation(placeId);
      if (!mounted) return;
      setState(() {
        _latitude = loc?['lat'];
        _longitude = loc?['lng'];
        _resolvingLocation = false;
      });
    } catch (e) {
      AppLogger.e('Error fetching place location: $e');
      if (!mounted) return;
      setState(() => _resolvingLocation = false);
    }
  }

  /// Shows what was resolved for the chosen address, so the provider can see
  /// the listing is actually pinned rather than trusting it silently.
  Widget _locationStatus() {
    if (!_resolvingLocation && !_hasCoordinates) return const SizedBox.shrink();

    final resolving = _resolvingLocation;
    final color = resolving ? AppPalette.textGrey : AppPalette.green;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          if (resolving)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Iconsax.gps, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              resolving
                  ? 'Locating address…'
                  : 'Location pinned · '
                      '${_latitude!.toStringAsFixed(6)}, '
                      '${_longitude!.toStringAsFixed(6)}',
              style: AppText.caption.on(color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Switch between searching Places and typing the address and coordinates in.
  ///
  /// Whatever the provider had entered carries across in both directions, so
  /// flipping the mode never silently discards their work: a resolved pin seeds
  /// the coordinate fields, and a complete manual pair becomes the listing's
  /// resolved pin.
  void _toggleManualLocation() {
    FocusScope.of(context).unfocus();
    setState(() {
      if (!_manualLocation) {
        _latCtrl.text = _latitude?.toString() ?? '';
        _lngCtrl.text = _longitude?.toString() ?? '';
        // No half-resolved lookup should survive into manual mode: it would
        // land its coordinates on top of whatever is typed here.
        _pendingLocationLookup = null;
        _resolvingLocation = false;
        _suggestions = [];
        _manualLocation = true;
        return;
      }

      // Back to Places. A complete, valid manual pair keeps its pin; anything
      // else has nothing to hand over.
      final parsed = _parseManualCoordinates();
      _latitude = parsed.error == null ? parsed.latitude : null;
      _longitude = parsed.error == null ? parsed.longitude : null;
      _manualLocation = false;
    });
  }

  /// Read the hand-typed coordinate pair.
  ///
  /// Both fields empty is a valid answer — the provider gave an address without
  /// a pin, exactly as a listing saved before the Places flow. Anything else
  /// must be a complete, in-range pair: half a coordinate is not a location,
  /// and an out-of-range value is a typo, not a place. Zero is a real
  /// coordinate and is preserved as one.
  ({double? latitude, double? longitude, String? error})
  _parseManualCoordinates() {
    final lat = _latCtrl.text.trim();
    final lng = _lngCtrl.text.trim();

    if (lat.isEmpty && lng.isEmpty) {
      return (latitude: null, longitude: null, error: null);
    }
    if (lat.isEmpty || lng.isEmpty) {
      return (
        latitude: null,
        longitude: null,
        error: 'Enter both latitude and longitude, or leave both blank.',
      );
    }

    final latitude = double.tryParse(lat);
    final longitude = double.tryParse(lng);
    if (latitude == null || longitude == null) {
      return (
        latitude: null,
        longitude: null,
        error: 'Latitude and longitude must be numbers, e.g. 19.076090.',
      );
    }
    if (latitude < -90 || latitude > 90) {
      return (
        latitude: null,
        longitude: null,
        error: 'Latitude must be between -90 and 90.',
      );
    }
    if (longitude < -180 || longitude > 180) {
      return (
        latitude: null,
        longitude: null,
        error: 'Longitude must be between -180 and 180.',
      );
    }

    return (latitude: latitude, longitude: longitude, error: null);
  }

  /// The manual pair's problem, or null when it is fine (including both blank).
  ///
  /// Only applies in manual mode: in Places mode the coordinates come from the
  /// picked place and these fields are not on screen.
  String? _manualCoordinateError() =>
      _manualLocation ? _parseManualCoordinates().error : null;

  Widget _locationSection() {
    return _sectionCard(
      title: 'Location',
      icon: Iconsax.location,
      children: [
        Row(
          children: [
            Text('Business Address', style: AppText.label),
            const Spacer(),
            GestureDetector(
              onTap: _toggleManualLocation,
              child: Text(
                _manualLocation
                    ? 'Search with Google Maps instead'
                    : 'Enter address & coordinates manually',
                style: AppText.caption.on(AppPalette.primary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_manualLocation) ...[
          TextFormField(
            controller: _addressCtrl,
            style: AppText.body.on(AppPalette.textDark),
            decoration: _inputDecoration(
              hint: 'Shop 4, MIDC Road, Bhiwandi, Maharashtra',
              suffix: const Icon(
                Iconsax.location,
                color: AppPalette.primary,
                size: 20,
              ),
            ),
          ),
          AppSpacing.vGapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  label: 'Latitude',
                  controller: _latCtrl,
                  hint: '19.076090',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  // The pair is validated as a whole — half a coordinate is not
                  // a location — so both fields report the same verdict, and
                  // `_save` re-checks it as the authority.
                  validator: (_) => _manualCoordinateError(),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: _field(
                  label: 'Longitude',
                  controller: _lngCtrl,
                  hint: '72.877426',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (_) => _manualCoordinateError(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Coordinates are optional, but entering them lets customers '
            'navigate straight to you. Leave both blank to save the address on '
            'its own. Fill in the City below as well.',
            style: AppText.caption,
          ),
        ] else ...[
          TextFormField(
            controller: _addressCtrl,
            style: AppText.body.on(AppPalette.textDark),
            decoration: _inputDecoration(
              hint: 'Search for your business address',
              suffix: const Icon(Iconsax.location, color: AppPalette.primary, size: 20),
            ),
            onChanged: (value) async {
              // Typing over a resolved address invalidates its pin — the text
              // no longer describes the place those coordinates point at. Drop
              // them so a stale location can never be saved silently.
              if (_hasCoordinates) {
                setState(() {
                  _latitude = null;
                  _longitude = null;
                });
              }
              if (value.isEmpty) {
                setState(() => _suggestions = []);
                return;
              }
              try {
                final results = await _places.fetchSuggestions(value);
                if (mounted) setState(() => _suggestions = results);
              } catch (e) {
                AppLogger.e('Error fetching address suggestions: $e');
              }
            },
          ),
          _locationStatus(),
        ],
        if (!_manualLocation && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppPalette.card,
              borderRadius: AppRadius.rLg,
              border: Border.all(color: AppPalette.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppPalette.border),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Iconsax.location,
                      color: AppPalette.primary, size: 18),
                  title: Text(s.description,
                      style: AppText.bodySm.on(AppPalette.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: s.subTitle.isEmpty
                      ? null
                      : Text(s.subTitle,
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  onTap: () => _selectSuggestion(s),
                );
              },
            ),
          ),
        AppSpacing.vGapLg,
        _field(
          label: 'City *',
          controller: _cityCtrl,
          hint: 'City',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'City is required' : null,
        ),
      ],
    );
  }

  Widget _gallerySection() {
    return _sectionCard(
      title: 'Image Gallery',
      icon: Iconsax.gallery,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1,
          ),
          itemCount: _imageCount < 4 ? _imageCount + 1 : 4,
          itemBuilder: (context, i) {
            if (i < _existingImages.length) {
              return _imageTile(
                child: Image.network(_existingImages[i], fit: BoxFit.cover),
                onRemove: () => setState(() => _existingImages.removeAt(i)),
              );
            }
            final fileIdx = i - _existingImages.length;
            if (fileIdx < _newImages.length) {
              return _imageTile(
                child: Image.file(_newImages[fileIdx], fit: BoxFit.cover),
                onRemove: () => setState(() => _newImages.removeAt(fileIdx)),
              );
            }
            return _addImageTile();
          },
        ),
        AppSpacing.vGapSm,
        Text('Max 4 images · JPG/PNG · 2MB each', style: AppText.caption),
      ],
    );
  }

  Widget _visibilitySection() {
    return _sectionCard(
      title: '',
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppPalette.greenBg, borderRadius: AppRadius.rMd),
              child: const Icon(Iconsax.eye, color: AppPalette.green, size: 20),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Visibility', style: AppText.subtitle),
                  Text(
                      _isVisible
                          ? 'Published — visible to companies'
                          : 'Hidden — saved as draft',
                      style: AppText.caption),
                ],
              ),
            ),
            Switch(
              value: _isVisible,
              activeThumbColor: AppPalette.green,
              onChanged: (v) => setState(() => _isVisible = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
          AppSpacing.md + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppPalette.card,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: Obx(() {
        final loading = _controller.isLoading.value;
        return Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Save as Draft',
                color: AppPalette.textGrey,
                onPressed: loading ? null : () => _save(publish: false),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              flex: 2,
              child: AppPrimaryButton(
                label: _isEdit ? 'Update Service' : 'List Service',
                icon: _isEdit ? Iconsax.tick_circle : Iconsax.add_circle,
                loading: loading,
                onPressed: () => _save(publish: true),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Reusable building blocks ───────────────────────────────────────────────

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: AppText.body.on(AppPalette.textDark),
          textInputAction:
              maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
          decoration: _inputDecoration(
            hint: hint,
            prefix: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: AppPalette.textFaint),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefix, Widget? suffix}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: AppRadius.rLg,
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body.on(AppPalette.textFaint),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppPalette.bg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppPalette.border),
      enabledBorder: border(AppPalette.border),
      focusedBorder: border(AppPalette.primary),
      errorBorder: border(AppPalette.danger),
      focusedErrorBorder: border(AppPalette.danger),
    );
  }

  Widget _categoryMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Category *', style: AppText.label),
            const Spacer(),
            Text(
              _selectedCategories.isEmpty
                  ? 'Select one or more'
                  : '${_selectedCategories.length} selected',
              style: AppText.caption.on(AppPalette.textFaint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _categoryOptions.map((c) {
            final selected = _selectedCategories.contains(c);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _selectedCategories.remove(c);
                } else {
                  _selectedCategories.add(c);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppPalette.primary : AppPalette.bg,
                  borderRadius: AppRadius.rPill,
                  border: Border.all(
                      color:
                          selected ? AppPalette.primary : AppPalette.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selected) ...[
                    const Icon(Iconsax.tick_circle,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 5),
                  ],
                  Text(c,
                      style: AppText.bodySm.weight(FontWeight.w600).on(
                          selected ? Colors.white : AppPalette.textGrey)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _pricingChip(String value, String label) {
    final selected = _pricingType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _pricingType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppPalette.primaryLight : AppPalette.bg,
            borderRadius: AppRadius.rLg,
            border: Border.all(
                color: selected ? AppPalette.primary : AppPalette.border,
                width: selected ? 1.4 : 1),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppText.bodySm.weight(FontWeight.w600).on(
                  selected ? AppPalette.primary : AppPalette.textGrey)),
        ),
      ),
    );
  }

  Widget _dayChip(String short, String full) {
    final selected = _selectedDays.contains(full);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedDays.remove(full);
        } else {
          _selectedDays.add(full);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppPalette.primary : AppPalette.bg,
          borderRadius: AppRadius.rPill,
          border: Border.all(
              color: selected ? AppPalette.primary : AppPalette.border),
        ),
        child: Text(short,
            style: AppText.bodySm
                .weight(FontWeight.w600)
                .on(selected ? Colors.white : AppPalette.textGrey)),
      ),
    );
  }

  Widget _timeField(String label, String value, bool isFrom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _pickTime(isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppPalette.bg,
              border: Border.all(color: AppPalette.border),
              borderRadius: AppRadius.rLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: AppText.body.on(AppPalette.textDark)),
                const Icon(Iconsax.clock, size: 18, color: AppPalette.textFaint),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageTile({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: AppRadius.rLg, child: child),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: AppPalette.danger, shape: BoxShape.circle),
              child: const Icon(Iconsax.trash, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addImageTile() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.primaryLight,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: AppPalette.primary.withValues(alpha: 0.4)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.gallery_add, color: AppPalette.primary),
            SizedBox(height: 6),
            Text('Add Image',
                style: TextStyle(
                    color: AppPalette.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickTime(bool isFrom) async {
    final parts = (isFrom ? _from : _to).split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final str =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => isFrom ? _from = str : _to = str);
    }
  }

  Future<void> _pickImage() async {
    if (_imageCount >= 4) {
      SnackBarHelper.error('Maximum 4 images allowed');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppPalette.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Iconsax.camera, color: AppPalette.primary),
            title: Text('Take Photo', style: AppText.subtitle),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Iconsax.gallery, color: AppPalette.primary),
            title: Text('Choose from Gallery', style: AppText.subtitle),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Iconsax.close_circle, color: AppPalette.textGrey),
            title: Text('Cancel', style: AppText.subtitle.on(AppPalette.textGrey)),
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
          source: source, imageQuality: 80, maxWidth: 1920, maxHeight: 1920);
      if (picked == null) return;
      final file = File(picked.path);
      final sizeMb = await file.length() / (1024 * 1024);
      if (sizeMb > 2) {
        SnackBarHelper.error('Image size should be less than 2MB');
        return;
      }
      setState(() => _newImages.add(file));
    } catch (e) {
      SnackBarHelper.error('Failed to pick image: $e');
    }
  }

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;

    // In manual mode the typed coordinates are the listing's pin. Validated
    // before anything else is done so a typo is reported next to the fields
    // that caused it, rather than after a payment or an upload.
    double? latitude = _latitude;
    double? longitude = _longitude;
    if (_manualLocation) {
      final parsed = _parseManualCoordinates();
      if (parsed.error != null) {
        SnackBarHelper.error(parsed.error!);
        return;
      }
      latitude = parsed.latitude;
      longitude = parsed.longitude;
    } else if (_pendingLocationLookup != null) {
      // A just-tapped address may still be resolving. Awaiting it here is the
      // difference between saving the listing with its pin and saving the text
      // alone — the lookup is already bounded by its own request timeout.
      await _pendingLocationLookup;
      if (!mounted) return;
      latitude = _latitude;
      longitude = _longitude;
    }

    if (_selectedCategories.isEmpty) {
      SnackBarHelper.error('Please select at least one category');
      return;
    }

    if (_selectedDays.isEmpty) {
      SnackBarHelper.error('Please select at least one working day');
      return;
    }

    final userId = AuthService.to.userId;
    if (userId.isEmpty) {
      SnackBarHelper.error('User ID not found. Please login again.');
      return;
    }

    final user = AuthService.to.currentUser.value;
    final businessName = (user?.profile['businessName'] ??
            user?.profile['companyName'] ??
            (user?.fullName.isNotEmpty == true ? user!.fullName : null) ??
            'My Business')
        .toString();

    final amount = _pricingType == 'On Request'
        ? null
        : double.tryParse(_priceCtrl.text.trim());

    final address = _addressCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final location = address.isNotEmpty ? address : city;

    // Multi-select → backend single `category` string (comma-joined) + `tags[]`.
    final categories = _selectedCategories.toList();
    final payload = ServicePayload(
      title: _titleCtrl.text.trim(),
      category: categories.join(', '),
      categoryColor: ServicePayload.colorForCategory(categories.first),
      description: _descriptionCtrl.text.trim(),
      status: publish ? 'Published' : 'Draft',
      businessId: userId,
      businessName: businessName,
      pricingType: _pricingType,
      amount: amount,
      pricingDetails: _detailsCtrl.text.trim().isEmpty
          ? null
          : _detailsCtrl.text.trim(),
      days: _selectedDays.toList(),
      hours: '$_from - $_to',
      location: location,
      latitude: latitude,
      longitude: longitude,
      phone: _contactCtrl.text.trim(),
      email: null,
      existingImages: _existingImages,
      newImages: _newImages,
      tags: categories,
    );

    HapticFeedback.lightImpact();

    final result = _isEdit
        ? await _controller.updateService(widget.service!.serviceId, payload)
        : await _controller.addService(payload);

    if (result != null && result['success'] == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// Lightweight staggered fade + slide-up entrance for form sections.
class _FadeInUp extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeInUp({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}
