import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';

class PricingBreakdown {
  final double subtotal;
  final double stripeFee;
  final double platformFee;
  final double taxAmount;
  final double total;
  final double photographerNet;

  const PricingBreakdown({
    required this.subtotal,
    required this.stripeFee,
    required this.platformFee,
    required this.taxAmount,
    required this.total,
    required this.photographerNet,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'subtotal': subtotal,
      'stripeFee': stripeFee,
      'platformFee': platformFee,
      'taxAmount': taxAmount,
      'total': total,
      'photographerNet': photographerNet,
    };
  }
}

class MediaPricingService {
  const MediaPricingService();

  PricingBreakdown computePhotoOrderPricing({
    required List<MediaPhotoModel> photos,
    double commissionRate = 0,
    double stripeRate = 0.029,
    double stripeFixedFee = 0.30,
    double taxRate = 0,
  }) {
    final subtotal = photos.fold<double>(
      0,
      (sum, photo) => sum + photo.unitPrice,
    );
    return computeCheckoutBreakdown(
      subtotal: subtotal,
      commissionRate: commissionRate,
      stripeRate: stripeRate,
      stripeFixedFee: photos.isEmpty ? 0 : stripeFixedFee,
      taxRate: taxRate,
    );
  }

  PricingBreakdown computePackOrderPricing({
    required List<MediaPackModel> packs,
    double commissionRate = 0,
    double stripeRate = 0.029,
    double stripeFixedFee = 0.30,
    double taxRate = 0,
  }) {
    final subtotal = packs.fold<double>(0, (sum, pack) => sum + pack.price);
    return computeCheckoutBreakdown(
      subtotal: subtotal,
      commissionRate: commissionRate,
      stripeRate: stripeRate,
      stripeFixedFee: packs.isEmpty ? 0 : stripeFixedFee,
      taxRate: taxRate,
    );
  }

  PricingBreakdown computeCheckoutBreakdown({
    required double subtotal,
    double commissionRate = 0,
    double stripeRate = 0.029,
    double stripeFixedFee = 0.30,
    double taxRate = 0,
  }) {
    final normalizedSubtotal = subtotal < 0 ? 0 : subtotal;
    final taxAmount = normalizedSubtotal * taxRate;
    final subtotalWithTax = normalizedSubtotal + taxAmount;
    final stripeFee = subtotalWithTax > 0
        ? (subtotalWithTax * stripeRate) + stripeFixedFee
        : 0;
    final platformFee = normalizedSubtotal * commissionRate;
    final total = subtotalWithTax;
    final photographerNetRaw = normalizedSubtotal - platformFee - stripeFee;
    final photographerNet =
        photographerNetRaw < 0 ? 0.0 : photographerNetRaw;

    return PricingBreakdown(
      subtotal: normalizedSubtotal.toDouble(),
      stripeFee: stripeFee.toDouble(),
      platformFee: platformFee,
      taxAmount: taxAmount,
      total: total,
      photographerNet: photographerNet.toDouble(),
    );
  }
}