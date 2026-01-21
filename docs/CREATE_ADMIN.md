# Guide de création d'administrateur MASLIVE

## 🎯 Hiérarchie des rôles

1. **superAdmin** (priorité 100) - Tous les droits
2. **admin** (priorité 90) - Gestion complète du système
3. **group** (priorité 50) - Administrateur de groupe
4. **tracker** (priorité 20) - Utilisateur avec tracking
5. **user** (priorité 10) - Utilisateur standard

## 📝 Méthode 1 : Firebase Console (Recommandé pour le premier admin)

### Étapes :

1. **Créer le compte utilisateur** (si pas encore créé)
   - Allez sur Firebase Console → Authentication
   - Cliquez "Add user"
   - Entrez email et mot de passe
   - Notez l'UID de l'utilisateur

2. **Promouvoir en administrateur**
   - Allez sur Firestore Database
   - Collection `users` → Document avec l'UID de l'utilisateur
   - Si le document n'existe pas, créez-le
   - Ajoutez/modifiez ces champs :
     ```
     role: "superAdmin"
     isAdmin: true
     email: "votre@email.com"
     displayName: "Nom Admin"
     createdAt: [timestamp]
     updatedAt: [timestamp]
     ```

## 💻 Méthode 2 : Script Node.js (Automatisé)

### Installation :

```bash
cd /workspaces/MASLIVE
npm install firebase-admin
```

### Obtenir la clé de service :

1. Firebase Console → Project Settings → Service Accounts
2. Cliquez "Generate new private key"
3. Sauvegardez le fichier comme `serviceAccountKey.json` à la racine du projet
4. **⚠️ IMPORTANT** : Ajoutez à `.gitignore` :
   ```
   serviceAccountKey.json
   ```

### Utilisation :

```bash
# Créer un super administrateur
node scripts/create_admin.js admin@maslive.com superAdmin

# Créer un administrateur normal
node scripts/create_admin.js user@maslive.com admin
```

## 🔧 Méthode 3 : Via l'application Flutter

### Code Dart pour promouvoir un utilisateur :

```dart
import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  final _functions = FirebaseFunctions.instance;

  // Assigner le rôle admin (nécessite d'être déjà admin)
  Future<void> promoteToAdmin(String targetUserId, String role) async {
    try {
      final callable = _functions.httpsCallable('assignUserRole');
      final result = await callable.call({
        'targetUserId': targetUserId,
        'role': role, // 'admin' ou 'superAdmin'
      });
      
      print('✅ ${result.data['message']}');
    } catch (e) {
      print('❌ Erreur: $e');
      rethrow;
    }
  }

  // Initialiser les rôles par défaut (une seule fois)
  Future<void> initializeRoles() async {
    try {
      final callable = _functions.httpsCallable('initializeRoles');
      final result = await callable.call();
      
      print('✅ Rôles initialisés: ${result.data['stats']}');
    } catch (e) {
      print('❌ Erreur: $e');
      rethrow;
    }
  }
}
```

## 🎨 Méthode 4 : Interface admin (À créer)

Vous pouvez créer une page d'administration dans Flutter :

```dart
// Page pour promouvoir des utilisateurs
class UserManagementPage extends StatefulWidget {
  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _emailController = TextEditingController();
  String _selectedRole = 'admin';

  Future<void> _promoteUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    try {
      // Trouver l'utilisateur par email
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        throw 'Utilisateur non trouvé';
      }

      final userId = usersQuery.docs.first.id;

      // Promouvoir
      final callable = FirebaseFunctions.instance
          .httpsCallable('assignUserRole');
      await callable.call({
        'targetUserId': userId,
        'role': _selectedRole,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Utilisateur promu à $_selectedRole')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gestion utilisateurs')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email utilisateur'),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedRole,
              items: ['user', 'tracker', 'group', 'admin', 'superAdmin']
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedRole = value!),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _promoteUser,
              child: Text('Promouvoir'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🔐 Sécurité

Les règles Firestore garantissent que :
- Seul un **superAdmin** peut modifier les rôles via Firestore
- Seul un **admin** ou **superAdmin** peut utiliser `assignUserRole`
- Les utilisateurs normaux ne peuvent pas s'auto-promouvoir

## 🚀 Ordre recommandé

1. **Premier déploiement** : Créez manuellement le premier superAdmin via Firebase Console
2. **Initialisation** : Le superAdmin appelle `initializeRoles()` une fois
3. **Ensuite** : Utilisez les fonctions Cloud ou l'interface admin pour gérer les autres utilisateurs

## ✅ Vérification

Pour vérifier qu'un utilisateur est admin :

```dart
final user = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();

final role = user.data()?['role'];
final isAdmin = user.data()?['isAdmin'] == true;

print('Rôle: $role, Admin: $isAdmin');
```
