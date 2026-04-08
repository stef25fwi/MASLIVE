class PremiumPackage {
  const PremiumPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.priceString,
    this.platformPackage,
  });

  final String id;
  final String title;
  final String description;
  final String priceString;
  final Object? platformPackage;
}

class PremiumOfferings {
  const PremiumOfferings({required this.availablePackages});

  final List<PremiumPackage> availablePackages;

  bool get isEmpty => availablePackages.isEmpty;
}