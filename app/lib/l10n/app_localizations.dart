import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'MASLIVE'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez les événements en direct'**
  String get appSubtitle;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In fr, this message translates to:
  /// **'Espagnol'**
  String get spanish;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @map.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get map;

  /// No description provided for @maps.
  ///
  /// In fr, this message translates to:
  /// **'Cartes'**
  String get maps;

  /// No description provided for @profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In fr, this message translates to:
  /// **'Inscription'**
  String get signup;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié?'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In fr, this message translates to:
  /// **'Se souvenir de moi'**
  String get rememberMe;

  /// No description provided for @or.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get or;

  /// No description provided for @signInWith.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec'**
  String get signInWith;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas de compte?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte?'**
  String get alreadyHaveAccount;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get error;

  /// No description provided for @success.
  ///
  /// In fr, this message translates to:
  /// **'Succès'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In fr, this message translates to:
  /// **'Avertissement'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get info;

  /// No description provided for @noData.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée'**
  String get noData;

  /// No description provided for @tryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get tryAgain;

  /// No description provided for @selectLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une langue'**
  String get selectLanguage;

  /// No description provided for @changeLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Changer la langue'**
  String get changeLanguage;

  /// No description provided for @selectedLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue sélectionnée'**
  String get selectedLanguage;

  /// Message when language is changed
  ///
  /// In fr, this message translates to:
  /// **'Langue changée en {language}'**
  String languageChanged(String language);

  /// No description provided for @circuits.
  ///
  /// In fr, this message translates to:
  /// **'Circuits'**
  String get circuits;

  /// No description provided for @routes.
  ///
  /// In fr, this message translates to:
  /// **'Routes'**
  String get routes;

  /// No description provided for @events.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get events;

  /// No description provided for @artists.
  ///
  /// In fr, this message translates to:
  /// **'Artistes'**
  String get artists;

  /// No description provided for @galleries.
  ///
  /// In fr, this message translates to:
  /// **'Galeries'**
  String get galleries;

  /// No description provided for @shop.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get shop;

  /// No description provided for @favorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get favorites;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In fr, this message translates to:
  /// **'Tri'**
  String get sort;

  /// No description provided for @details.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get details;

  /// No description provided for @description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @duration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get duration;

  /// No description provided for @distance.
  ///
  /// In fr, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @difficulty.
  ///
  /// In fr, this message translates to:
  /// **'Difficulté'**
  String get difficulty;

  /// No description provided for @price.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get price;

  /// No description provided for @free.
  ///
  /// In fr, this message translates to:
  /// **'Gratuit'**
  String get free;

  /// No description provided for @buy.
  ///
  /// In fr, this message translates to:
  /// **'Acheter'**
  String get buy;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get remove;

  /// No description provided for @quantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get quantity;

  /// No description provided for @total.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @cart.
  ///
  /// In fr, this message translates to:
  /// **'Panier'**
  String get cart;

  /// No description provided for @checkout.
  ///
  /// In fr, this message translates to:
  /// **'Passer la commande'**
  String get checkout;

  /// No description provided for @payment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get payment;

  /// No description provided for @deliveryAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de livraison'**
  String get deliveryAddress;

  /// No description provided for @contactInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations de contact'**
  String get contactInfo;

  /// No description provided for @phoneNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get address;

  /// No description provided for @city.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get city;

  /// No description provided for @zipCode.
  ///
  /// In fr, this message translates to:
  /// **'Code postal'**
  String get zipCode;

  /// No description provided for @country.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get country;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications push'**
  String get pushNotifications;

  /// No description provided for @emailNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications par email'**
  String get emailNotifications;

  /// No description provided for @smsNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications SMS'**
  String get smsNotifications;

  /// No description provided for @privacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get terms;

  /// No description provided for @about.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get about;

  /// App version
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @helpCenter.
  ///
  /// In fr, this message translates to:
  /// **'Centre d\'aide'**
  String get helpCenter;

  /// No description provided for @contactUs.
  ///
  /// In fr, this message translates to:
  /// **'Nous contacter'**
  String get contactUs;

  /// No description provided for @reportBug.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un bug'**
  String get reportBug;

  /// No description provided for @feedback.
  ///
  /// In fr, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @rateApp.
  ///
  /// In fr, this message translates to:
  /// **'Évaluer l\'application'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In fr, this message translates to:
  /// **'Partager l\'application'**
  String get shareApp;

  /// No description provided for @darkMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode sombre'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode clair'**
  String get lightMode;

  /// No description provided for @theme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get theme;

  /// No description provided for @selectMap.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une carte'**
  String get selectMap;

  /// No description provided for @selectLayers.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner les couches'**
  String get selectLayers;

  /// No description provided for @viewMap.
  ///
  /// In fr, this message translates to:
  /// **'Voir la carte'**
  String get viewMap;

  /// No description provided for @apply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get apply;

  /// No description provided for @activeMap.
  ///
  /// In fr, this message translates to:
  /// **'Carte active'**
  String get activeMap;

  /// No description provided for @consultMap.
  ///
  /// In fr, this message translates to:
  /// **'Vous consultez la carte sélectionnée'**
  String get consultMap;

  /// No description provided for @chooseMap.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une carte et ses couches'**
  String get chooseMap;

  /// No description provided for @noMapsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune carte disponible'**
  String get noMapsAvailable;

  /// No description provided for @createMapEditor.
  ///
  /// In fr, this message translates to:
  /// **'Créez une carte depuis l\'éditeur'**
  String get createMapEditor;

  /// No description provided for @layers.
  ///
  /// In fr, this message translates to:
  /// **'Couches'**
  String get layers;

  /// No description provided for @visibleLayers.
  ///
  /// In fr, this message translates to:
  /// **'Couches visibles'**
  String get visibleLayers;

  /// No description provided for @hideLayers.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les couches'**
  String get hideLayers;

  /// No description provided for @connection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get connection;

  /// No description provided for @accessYourSpace.
  ///
  /// In fr, this message translates to:
  /// **'Accédez à votre espace'**
  String get accessYourSpace;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In fr, this message translates to:
  /// **'Connexion...'**
  String get signingIn;

  /// No description provided for @continueAsGuest.
  ///
  /// In fr, this message translates to:
  /// **'Continuer en invité'**
  String get continueAsGuest;

  /// No description provided for @createAccountWithEmail.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte avec email'**
  String get createAccountWithEmail;

  /// No description provided for @creating.
  ///
  /// In fr, this message translates to:
  /// **'Création...'**
  String get creating;

  /// No description provided for @continueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get continueWithApple;

  /// No description provided for @myFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Mes favoris'**
  String get myFavorites;

  /// No description provided for @myGroups.
  ///
  /// In fr, this message translates to:
  /// **'Mes groupes'**
  String get myGroups;

  /// No description provided for @savedPlacesGroups.
  ///
  /// In fr, this message translates to:
  /// **'Lieux et groupes enregistrés'**
  String get savedPlacesGroups;

  /// No description provided for @accessYourCommunities.
  ///
  /// In fr, this message translates to:
  /// **'Accéder à vos communautés'**
  String get accessYourCommunities;

  /// No description provided for @manageAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Gérer vos alertes'**
  String get manageAlerts;

  /// No description provided for @languagePrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Langue, confidentialité…'**
  String get languagePrivacy;

  /// No description provided for @help.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get help;

  /// No description provided for @faqSupport.
  ///
  /// In fr, this message translates to:
  /// **'FAQ & support'**
  String get faqSupport;

  /// No description provided for @administration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get administration;

  /// No description provided for @adminSpace.
  ///
  /// In fr, this message translates to:
  /// **'Espace Administrateur'**
  String get adminSpace;

  /// No description provided for @manageApp.
  ///
  /// In fr, this message translates to:
  /// **'Gérer l\'application'**
  String get manageApp;

  /// No description provided for @disconnect.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get disconnect;

  /// No description provided for @premiumMember.
  ///
  /// In fr, this message translates to:
  /// **'Premium Member'**
  String get premiumMember;

  /// No description provided for @noFavoritesYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori pour le moment.'**
  String get noFavoritesYet;

  /// No description provided for @place.
  ///
  /// In fr, this message translates to:
  /// **'Place'**
  String get place;

  /// No description provided for @searchLocation.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un lieu…'**
  String get searchLocation;

  /// No description provided for @noResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get noResults;

  /// No description provided for @type.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @premium.
  ///
  /// In fr, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @purchaseCancelledFailed.
  ///
  /// In fr, this message translates to:
  /// **'Achat annulé/échoué'**
  String get purchaseCancelledFailed;

  /// No description provided for @clearAllPoints.
  ///
  /// In fr, this message translates to:
  /// **'Effacer tous les points ?'**
  String get clearAllPoints;

  /// No description provided for @clear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clear;

  /// No description provided for @pointsTooClose.
  ///
  /// In fr, this message translates to:
  /// **'Points trop proches ?'**
  String get pointsTooClose;

  /// Warning about points too close
  ///
  /// In fr, this message translates to:
  /// **'{count} point(s) sont très proches. Continuer ?'**
  String pointsVeryClose(int count);

  /// No description provided for @continueButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueButton;

  /// No description provided for @routeSaved.
  ///
  /// In fr, this message translates to:
  /// **'Parcours enregistré'**
  String get routeSaved;

  /// No description provided for @drawRoute.
  ///
  /// In fr, this message translates to:
  /// **'Tracer un parcours'**
  String get drawRoute;

  /// No description provided for @points.
  ///
  /// In fr, this message translates to:
  /// **'points'**
  String get points;

  /// No description provided for @km.
  ///
  /// In fr, this message translates to:
  /// **'km'**
  String get km;

  /// No description provided for @saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get saving;

  /// No description provided for @normalMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode normal'**
  String get normalMode;

  /// No description provided for @openAdvancedSelector.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le sélecteur avancé'**
  String get openAdvancedSelector;

  /// No description provided for @menu.
  ///
  /// In fr, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @visit.
  ///
  /// In fr, this message translates to:
  /// **'Visiter'**
  String get visit;

  /// No description provided for @food.
  ///
  /// In fr, this message translates to:
  /// **'Restauration'**
  String get food;

  /// No description provided for @assistance.
  ///
  /// In fr, this message translates to:
  /// **'Assistance'**
  String get assistance;

  /// No description provided for @parking.
  ///
  /// In fr, this message translates to:
  /// **'Parking'**
  String get parking;

  /// No description provided for @tracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get tracking;

  /// No description provided for @theShop.
  ///
  /// In fr, this message translates to:
  /// **'La boutique'**
  String get theShop;

  /// No description provided for @merchStickersAccessories.
  ///
  /// In fr, this message translates to:
  /// **'Merch, stickers, accessoires & photos'**
  String get merchStickersAccessories;

  /// No description provided for @allGroups.
  ///
  /// In fr, this message translates to:
  /// **'Tous les groupes'**
  String get allGroups;

  /// No description provided for @searchArticle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un article, un groupe…'**
  String get searchArticle;

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get all;

  /// No description provided for @tshirts.
  ///
  /// In fr, this message translates to:
  /// **'T-shirts'**
  String get tshirts;

  /// No description provided for @caps.
  ///
  /// In fr, this message translates to:
  /// **'Casquettes'**
  String get caps;

  /// No description provided for @stickers.
  ///
  /// In fr, this message translates to:
  /// **'Stickers'**
  String get stickers;

  /// No description provided for @accessories.
  ///
  /// In fr, this message translates to:
  /// **'Accessoires'**
  String get accessories;

  /// No description provided for @group.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get group;

  /// No description provided for @filters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filters;

  /// No description provided for @newest.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés'**
  String get newest;

  /// No description provided for @priceAsc.
  ///
  /// In fr, this message translates to:
  /// **'Prix ↑'**
  String get priceAsc;

  /// No description provided for @priceDesc.
  ///
  /// In fr, this message translates to:
  /// **'Prix ↓'**
  String get priceDesc;

  /// No description provided for @azSort.
  ///
  /// In fr, this message translates to:
  /// **'A → Z'**
  String get azSort;

  /// No description provided for @noProductsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit trouvé'**
  String get noProductsFound;

  /// No description provided for @changeCategoryOrGroup.
  ///
  /// In fr, this message translates to:
  /// **'Change de catégorie, de groupe ou de recherche.'**
  String get changeCategoryOrGroup;

  /// No description provided for @shopPhotoStoreTitle.
  ///
  /// In fr, this message translates to:
  /// **'La Boutique Photo'**
  String get shopPhotoStoreTitle;

  /// No description provided for @shopBestSeller.
  ///
  /// In fr, this message translates to:
  /// **'Meilleures ventes'**
  String get shopBestSeller;

  /// No description provided for @shopSeeMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus  >'**
  String get shopSeeMore;

  /// No description provided for @myOrders.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get myOrders;

  /// No description provided for @orders.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get orders;

  /// No description provided for @orderNo.
  ///
  /// In fr, this message translates to:
  /// **'Commande n°'**
  String get orderNo;

  /// No description provided for @itemsLabel.
  ///
  /// In fr, this message translates to:
  /// **'articles'**
  String get itemsLabel;

  /// No description provided for @addToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au panier'**
  String get addToCart;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
