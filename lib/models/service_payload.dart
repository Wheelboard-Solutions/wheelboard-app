import 'dart:io';

import '../services/media_service.dart';

/// Request payload for creating / updating a service.
///
/// Mirrors the backend `CreateServiceDto` (JSON) consumed by `POST /services`
/// and `PATCH /services/:id` — the SAME contract the wheelboard-fe web app uses
/// (`servicesAPI.createService`). New images are uploaded to Firebase via the
/// unified `/media` endpoint first; only the resulting hosted URLs are sent in
/// the `images: string[]` field (alongside any already-stored URLs).
class ServicePayload {
  final String title;
  final String category;
  final String categoryColor;
  final String description;
  final String? detailedDescription;
  final String status; // 'Published' | 'Draft'
  final String businessId;
  final String businessName;

  // Pricing
  final String pricingType; // 'Fixed' | 'Hourly' | 'On Request'
  final double? amount; // omitted for 'On Request'
  final String? pricingDetails;

  // Availability
  final List<String> days; // full day names: Monday … Sunday
  final String hours; // "09:00 - 18:00"

  final String location;

  /// Coordinates of the selected business address, resolved through the same
  /// Google Places lookup a Transport user goes through for a trip's
  /// pickup/delivery point. Null when the address was typed by hand.
  final double? latitude;
  final double? longitude;

  final String? phone;
  final String? email;

  /// Already-stored image URLs/data-URLs to keep (edit mode).
  final List<String> existingImages;

  /// Newly picked image files to encode as base64 and append.
  final List<File> newImages;

  final List<String> tags;

  // Verified listing-fee payment (free-tier providers, on the 402 resubmit).
  final String? listingPaymentOrderId;
  final String? listingPaymentId;
  final String? listingPaymentSignature;

  const ServicePayload({
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.description,
    this.detailedDescription,
    required this.status,
    required this.businessId,
    required this.businessName,
    required this.pricingType,
    this.amount,
    this.pricingDetails,
    required this.days,
    required this.hours,
    required this.location,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.existingImages = const [],
    this.newImages = const [],
    this.tags = const [],
    this.listingPaymentOrderId,
    this.listingPaymentId,
    this.listingPaymentSignature,
  });

  /// Maps a UI category name to a soft badge colour.
  static String colorForCategory(String category) {
    switch (category) {
      case 'Brake Service':
        return '#FEE2E2';
      case 'Oil Change':
        return '#FEF3C7';
      case 'AC Repair':
        return '#E0F2FE';
      case 'Vehicle Service':
      case 'Vehicle Services':
        return '#FFF3E0';
      case 'Tyre Service':
      case 'Tyre Services':
        return '#F3E5F5';
      case 'Tyre Retreader':
        return '#E3F2FD';
      default:
        return '#FFEBEE';
    }
  }

  ServicePayload withListingPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    return ServicePayload(
      title: title,
      category: category,
      categoryColor: categoryColor,
      description: description,
      detailedDescription: detailedDescription,
      status: status,
      businessId: businessId,
      businessName: businessName,
      pricingType: pricingType,
      amount: amount,
      pricingDetails: pricingDetails,
      days: days,
      hours: hours,
      location: location,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      email: email,
      existingImages: existingImages,
      newImages: newImages,
      tags: tags,
      listingPaymentOrderId: orderId,
      listingPaymentId: paymentId,
      listingPaymentSignature: signature,
    );
  }

  /// Builds the JSON body. Encodes [newImages] to base64 data-URLs (async file
  /// reads), preserving any [existingImages] first.
  Future<Map<String, dynamic>> toJson() async {
    final images = <String>[...existingImages];
    for (final file in newImages) {
      final media = await MediaService.upload(file, folder: 'service-images');
      if (media != null && media.url.isNotEmpty) images.add(media.url);
    }

    final Map<String, dynamic> pricing = pricingType == 'On Request'
        ? {
            'currency': '₹',
            if (pricingDetails != null && pricingDetails!.isNotEmpty)
              'details': pricingDetails,
            'type': 'On Request',
          }
        : {
            if (amount != null) 'amount': amount,
            'currency': '₹',
            if (pricingDetails != null && pricingDetails!.isNotEmpty)
              'details': pricingDetails,
            'type': pricingType,
          };

    final Map<String, dynamic> body = {
      'title': title,
      'category': category,
      'categoryColor': categoryColor,
      'description': description,
      if (detailedDescription != null && detailedDescription!.isNotEmpty)
        'detailedDescription': detailedDescription,
      'status': status,
      'businessId': businessId,
      'businessName': businessName,
      'pricing': pricing,
      'availability': {'days': days, 'hours': hours},
      'location': location,
      // Always sent, null included. On edit this is what clears a stale pin
      // when the provider retypes the address without picking a place —
      // omitting the keys would leave PATCH pointing at the previous shop.
      'latitude': latitude,
      'longitude': longitude,
      'contactInfo': {
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
      },
      'images': images,
      'tags': tags,
    };

    if (listingPaymentOrderId != null && listingPaymentOrderId!.isNotEmpty) {
      body['listingPayment'] = {
        'orderId': listingPaymentOrderId,
        'paymentId': listingPaymentId ?? '',
        'signature': listingPaymentSignature ?? '',
      };
    }

    return body;
  }
}
