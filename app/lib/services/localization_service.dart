import 'package:flutter/material.dart';

enum AppLanguage { fr, en, es }

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._();
  factory LocalizationService() => _instance;
  LocalizationService._();

  AppLanguage _language = AppLanguage.fr;
  AppLanguage get language => _language;

  void setLanguage(AppLanguage lang) {
    if (_language != lang) {
      _language = lang;
      notifyListeners();
    }
  }

  String get languageCode {
    switch (_language) {
      case AppLanguage.fr:
        return 'fr';
      case AppLanguage.en:
        return 'en';
      case AppLanguage.es:
        return 'es';
    }
  }

  String get languageLabel {
    switch (_language) {
      case AppLanguage.fr:
        return 'Français';
      case AppLanguage.en:
        return 'English';
      case AppLanguage.es:
        return 'Español';
    }
  }
}

class AppLocalizations {
  static final AppLocalizations _instance = AppLocalizations._();
  factory AppLocalizations() => _instance;
  AppLocalizations._();

  final _localizationService = LocalizationService();

  static const Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.fr: {
      // Navigation
      'nav_home': 'Accueil',
      'nav_map': 'Carte',
      'nav_shop': 'Shop',
      'nav_account': 'Compte',
      'nav_orders': 'Commandes',
      'nav_admin': 'Admin',
      'nav_language': 'Langue',

      // Home
      'home_title': 'Bienvenue',
      'home_subtitle': 'Explorez les POIs et circuits',

      // Shop
      'shop_title': 'Shop Groupe',
      'shop_all_categories': 'Tous',
      'shop_no_products': 'Aucun produit disponible',
      'shop_add_to_cart': 'Ajouter au panier',

      // Account
      'account_title': 'Mon compte',
      'account_profile': 'Mon profil',
      'account_favorites': 'Mes favoris',
      'account_history': 'Historique',
      'account_logout': 'Déconnexion',
      'account_admin_space': 'Espace Admin',
      'account_edit_profile': 'Modifier mon profil',

      // Orders
      'orders_title': 'Mes commandes',
      'orders_no_orders': 'Aucune commande',
      'orders_order_id': 'Commande',
      'orders_status': 'Statut',
      'orders_pending': 'En attente',
      'orders_confirmed': 'Confirmée',
      'orders_shipped': 'Expédiée',
      'orders_delivered': 'Livrée',
      'orders_cancelled': 'Annulée',

      // Admin
      'admin_title': 'Tableau de bord Admin',
      'admin_add_poi': 'Ajouter POI',
      'admin_create_circuit': 'Créer circuit',
      'admin_set_start_end': 'Départ/Arrivée',
      'admin_moderation': 'Modération',
      'admin_map_editor': 'Editeur carte',

      // Common
      'common_ok': 'OK',
      'common_cancel': 'Annuler',
      'common_save': 'Enregistrer',
      'common_delete': 'Supprimer',
      'common_edit': 'Modifier',
      'common_loading': 'Chargement...',
      'common_error': 'Erreur',
      'common_success': 'Succès',
      'common_close': 'Fermer',
      'common_back': 'Retour',
    },
    AppLanguage.en: {
      // Navigation
      'nav_home': 'Home',
      'nav_map': 'Map',
      'nav_shop': 'Shop',
      'nav_account': 'Account',
      'nav_orders': 'Orders',
      'nav_admin': 'Admin',
      'nav_language': 'Language',

      // Home
      'home_title': 'Welcome',
      'home_subtitle': 'Explore POIs and circuits',

      // Shop
      'shop_title': 'Group Shop',
      'shop_all_categories': 'All',
      'shop_no_products': 'No products available',
      'shop_add_to_cart': 'Add to cart',

      // Account
      'account_title': 'My account',
      'account_profile': 'My profile',
      'account_favorites': 'My favorites',
      'account_history': 'History',
      'account_logout': 'Logout',
      'account_admin_space': 'Admin Space',
      'account_edit_profile': 'Edit profile',

      // Orders
      'orders_title': 'My orders',
      'orders_no_orders': 'No orders',
      'orders_order_id': 'Order',
      'orders_status': 'Status',
      'orders_pending': 'Pending',
      'orders_confirmed': 'Confirmed',
      'orders_shipped': 'Shipped',
      'orders_delivered': 'Delivered',
      'orders_cancelled': 'Cancelled',

      // Admin
      'admin_title': 'Admin Dashboard',
      'admin_add_poi': 'Add POI',
      'admin_create_circuit': 'Create circuit',
      'admin_set_start_end': 'Start/End',
      'admin_moderation': 'Moderation',
      'admin_map_editor': 'Map editor',

      // Common
      'common_ok': 'OK',
      'common_cancel': 'Cancel',
      'common_save': 'Save',
      'common_delete': 'Delete',
      'common_edit': 'Edit',
      'common_loading': 'Loading...',
      'common_error': 'Error',
      'common_success': 'Success',
      'common_close': 'Close',
      'common_back': 'Back',
    },
    AppLanguage.es: {
      // Navigation
      'nav_home': 'Inicio',
      'nav_map': 'Mapa',
      'nav_shop': 'Tienda',
      'nav_account': 'Cuenta',
      'nav_orders': 'Pedidos',
      'nav_admin': 'Admin',
      'nav_language': 'Idioma',

      // Home
      'home_title': 'Bienvenido',
      'home_subtitle': 'Explora POIs y circuitos',

      // Shop
      'shop_title': 'Tienda del Grupo',
      'shop_all_categories': 'Todos',
      'shop_no_products': 'Sin productos disponibles',
      'shop_add_to_cart': 'Agregar al carrito',

      // Account
      'account_title': 'Mi cuenta',
      'account_profile': 'Mi perfil',
      'account_favorites': 'Mis favoritos',
      'account_history': 'Historial',
      'account_logout': 'Cerrar sesión',
      'account_admin_space': 'Espacio Admin',
      'account_edit_profile': 'Editar perfil',

      // Orders
      'orders_title': 'Mis pedidos',
      'orders_no_orders': 'Sin pedidos',
      'orders_order_id': 'Pedido',
      'orders_status': 'Estado',
      'orders_pending': 'Pendiente',
      'orders_confirmed': 'Confirmado',
      'orders_shipped': 'Enviado',
      'orders_delivered': 'Entregado',
      'orders_cancelled': 'Cancelado',

      // Admin
      'admin_title': 'Panel de Control Admin',
      'admin_add_poi': 'Agregar POI',
      'admin_create_circuit': 'Crear circuito',
      'admin_set_start_end': 'Inicio/Fin',
      'admin_moderation': 'Moderación',
      'admin_map_editor': 'Editor de mapa',

      // Common
      'common_ok': 'OK',
      'common_cancel': 'Cancelar',
      'common_save': 'Guardar',
      'common_delete': 'Eliminar',
      'common_edit': 'Editar',
      'common_loading': 'Cargando...',
      'common_error': 'Error',
      'common_success': 'Éxito',
      'common_close': 'Cerrar',
      'common_back': 'Atrás',
    },
  };

  String translate(String key) {
    final lang = _localizationService.language;
    return _translations[lang]?[key] ?? key;
  }

  String t(String key) => translate(key);
}
