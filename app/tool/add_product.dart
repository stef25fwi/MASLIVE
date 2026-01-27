import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;

  // Ajouter le produit Casquette
  await db.collection('products').add({
    'title': 'Casquette MASLIVE',
    'category': 'Casquettes',
    'priceCents': 1500, // 15€
    'imagePath': 'assets/shop/capblack.png',
    'imageUrl': '',
    'imageUrl2': '',
    'description': 'Casquette noire MASLIVE Premium',
    'availableSizes': ['One Size'],
    'availableColors': ['Noir'],
    'stockByVariant': {
      'One Size|Noir': 50,
    },
    'moderationStatus': 'approved',
    'isActive': true,
    'groupId': 'maslive_official',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  print('✅ Produit Casquette ajouté avec succès!');
  exit(0);
}
