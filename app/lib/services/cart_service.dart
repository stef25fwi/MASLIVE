import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CartService extends ChangeNotifier {
  CartService._();
  static final instance = CartService._();

  final Map<String, CartItem> _itemsByKey = <String, CartItem>{};

  StreamSubscription<User?>? _authSub;
  Timer? _syncTimer;
  String? _uid;
  bool _hydrating = false;

  List<CartItem> get items => _itemsByKey.values.toList(growable: false);

  int get totalCents {
    var total = 0;
    for (final item in _itemsByKey.values) {
      total += item.priceCents * item.quantity;
    }
    return total;
  }

  String get totalLabel => '€${(totalCents / 100).toStringAsFixed(0)}';

  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  CollectionReference<Map<String, dynamic>> _cartCol(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('cart');
  }

  Future<void> _onAuthChanged(User? user) async {
    _syncTimer?.cancel();
    _syncTimer = null;

    if (user == null) {
      _uid = null;
      clear();
      return;
    }

    _uid = user.uid;
    await _loadFromFirestore(user.uid);
  }

  Future<void> _loadFromFirestore(String uid) async {
    _hydrating = true;
    try {
      final snap = await _cartCol(uid).get();
      _itemsByKey
        ..clear()
        ..addEntries(
          snap.docs.map((d) {
            final data = d.data();
            final item = CartItem(
              groupId: (data['groupId'] ?? '') as String,
              productId: (data['productId'] ?? '') as String,
              title: (data['title'] ?? '') as String,
              priceCents: (data['priceCents'] ?? 0) as int,
              imageUrl: (data['imageUrl'] ?? '') as String,
              imagePath: data['imagePath'] as String?, // Support assets locaux
              size: (data['size'] ?? 'M') as String,
              color: (data['color'] ?? 'Noir') as String,
              quantity: (data['quantity'] ?? 1) as int,
            );
            return MapEntry(item.key, item);
          }),
        );
    } finally {
      _hydrating = false;
      notifyListeners();
    }
  }

  void _afterLocalMutation() {
    notifyListeners();
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_hydrating) return;
    final uid = _uid;
    if (uid == null) return;

    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 350), () {
      _syncToFirestore(uid);
    });
  }

  Future<void> _syncToFirestore(String uid) async {
    if (_hydrating) return;
    final batch = FirebaseFirestore.instance.batch();
    final col = _cartCol(uid);

    final remote = await col.get();
    final localKeys = _itemsByKey.keys.toSet();

    for (final doc in remote.docs) {
      if (!localKeys.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    for (final item in _itemsByKey.values) {
      batch.set(
        col.doc(item.key),
        {
          'groupId': item.groupId,
          'productId': item.productId,
          'title': item.title,
          'priceCents': item.priceCents,
          'imageUrl': item.imageUrl,
          'imagePath': item.imagePath, // Support assets locaux
          'size': item.size,
          'color': item.color,
          'quantity': item.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  void addProduct({
    required String groupId,
    required GroupProduct product,
    required String size,
    required String color,
    int quantity = 1,
  }) {
    final next = CartItem(
      groupId: groupId,
      productId: product.id,
      title: product.title,
      priceCents: product.priceCents,
      imageUrl: product.imageUrl,
      size: size,
      color: color,
      quantity: quantity,
    );

    final existing = _itemsByKey[next.key];
    if (existing != null) {
      _itemsByKey[next.key] = existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      _itemsByKey[next.key] = next;
    }
    _afterLocalMutation();
  }

  void removeKey(String key) {
    _itemsByKey.remove(key);
    _afterLocalMutation();
  }

  void setQuantity(String key, int quantity) {
    final existing = _itemsByKey[key];
    if (existing == null) return;

    if (quantity <= 0) {
      _itemsByKey.remove(key);
    } else {
      _itemsByKey[key] = existing.copyWith(quantity: quantity);
    }
    _afterLocalMutation();
  }

  void clear() {
    _itemsByKey.clear();
    _afterLocalMutation();
  }

  /// Valide que tous les articles du panier ont du stock disponible
  /// Retourne une liste des articles problématiques
  Future<List<String>> validateStock() async {
    final problematicItems = <String>[];
    
    for (final item in _itemsByKey.values) {
      try {
        // Récupérer le produit depuis Firestore pour vérifier le stock actuel
        final productDoc = await FirebaseFirestore.instance
            .collectionGroup('products')
            .where('id', isEqualTo: item.productId)
            .limit(1)
            .get();
        
        if (productDoc.docs.isEmpty) {
          problematicItems.add('${item.title}: produit introuvable');
          continue;
        }
        
        final productData = productDoc.docs.first.data();
        final stockByVariant = productData['stockByVariant'] as Map<String, dynamic>?;
        
        if (stockByVariant == null) {
          continue; // Pas de gestion de stock
        }
        
        final variantKey = '${item.size}|${item.color}';
        final stock = stockByVariant[variantKey] as int? ?? 0;
        
        if (stock < item.quantity) {
          problematicItems.add(
            '${item.title} (${item.size}, ${item.color}): stock insuffisant (dispo: $stock, demandé: ${item.quantity})'
          );
        }
      } catch (e) {
        debugPrint('Error validating stock for ${item.productId}: $e');
        problematicItems.add('${item.title}: erreur de validation');
      }
    }
    
    return problematicItems;
  }

  /// Créer une commande et obtenir l'URL de checkout Stripe
  Future<String?> createCheckoutSession(String userId) async {
    if (_itemsByKey.isEmpty) return null;

    // Valider le stock avant de créer la session
    final stockIssues = await validateStock();
    if (stockIssues.isNotEmpty) {
      throw Exception('Stock insuffisant:\n${stockIssues.join('\n')}');
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('createMediaShopCheckout');

      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
      });

      final data = result.data;
      return data['checkoutUrl'] as String?;
    } catch (e) {
      debugPrint('Error creating checkout: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
