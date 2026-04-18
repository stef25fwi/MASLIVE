import 'package:flutter/foundation.dart';

class BloomArtNotificationService {
  const BloomArtNotificationService();

  Future<void> notifySellerOfferReceived({
    required String sellerId,
    required String itemId,
    required String offerId,
  }) async {
    // TODO: brancher ici votre backend FCM/email existant si vous souhaitez
    // declencher une notification cote app en plus des Cloud Functions.
    debugPrint(
      '[BloomArtNotificationService] notifySellerOfferReceived sellerId=$sellerId itemId=$itemId offerId=$offerId',
    );
  }

  Future<void> notifyBuyerOfferAccepted({
    required String buyerId,
    required String offerId,
  }) async {
    debugPrint(
      '[BloomArtNotificationService] notifyBuyerOfferAccepted buyerId=$buyerId offerId=$offerId',
    );
  }

  Future<void> notifyBuyerOfferDeclined({
    required String buyerId,
    required String offerId,
  }) async {
    debugPrint(
      '[BloomArtNotificationService] notifyBuyerOfferDeclined buyerId=$buyerId offerId=$offerId',
    );
  }

  Future<void> notifyBuyerOfferAutoAccepted({
    required String buyerId,
    required String offerId,
  }) async {
    debugPrint(
      '[BloomArtNotificationService] notifyBuyerOfferAutoAccepted buyerId=$buyerId offerId=$offerId',
    );
  }
}