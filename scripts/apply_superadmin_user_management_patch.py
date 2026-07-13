from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"{relative_path}: remplacement attendu une fois, trouvé {count}\n--- OLD ---\n{old}"
        )
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "functions/index.js",
    'const createBloomArtHandlers = require("./src/bloom-art");\n',
    'const createBloomArtHandlers = require("./src/bloom-art");\n'
    'const createSuperAdminUserManagementHandlers = require("./src/superadmin-user-management");\n',
)

replace_once(
    "functions/index.js",
    'const groupTracking = require("./group_tracking");\n'
    'exports.calculateGroupAveragePosition = groupTracking.calculateGroupAveragePosition;\n'
    'exports.publishGroupAverageToCircuit = groupTracking.publishGroupAverageToCircuit;\n',
    'const groupTracking = require("./group_tracking");\n'
    'exports.calculateGroupAveragePosition = groupTracking.calculateGroupAveragePosition;\n'
    'exports.publishGroupAverageToCircuit = groupTracking.publishGroupAverageToCircuit;\n\n'
    'const superAdminUserManagement = createSuperAdminUserManagementHandlers({\n'
    '  admin,\n'
    '  db,\n'
    '  onCall,\n'
    '  HttpsError,\n'
    '  logger,\n'
    '});\n'
    'Object.assign(exports, superAdminUserManagement);\n',
)

replace_once(
    "app/lib/services/auth_service.dart",
    '''  // Déconnexion\n  Future<void> signOut() async {\n    try {\n      // Also clear Google provider session when present.\n      try {\n        await GoogleSignIn.instance.signOut();\n      } catch (_) {\n        // Ignore: user may not be signed in with Google.\n      }\n      await _auth.signOut();\n    } catch (e) {\n      // print('Erreur signOut: $e');\n      rethrow;\n    }\n  }\n''',
    '''  // Déconnexion : Firebase est invalidé en premier pour que l'UI réagisse\n  // immédiatement, même si le SDK Google n'est pas initialisé ou répond lentement.\n  Future<void> signOut() async {\n    await _auth.signOut();\n    try {\n      await GoogleSignIn.instance\n          .signOut()\n          .timeout(const Duration(seconds: 2));\n    } catch (_) {\n      // La session Firebase est déjà fermée : une erreur provider ne doit pas\n      // empêcher la déconnexion visible dans l'application.\n    }\n  }\n''',
)

replace_once(
    "app/lib/pages/account_page.dart",
    '''class _AccountUiPageState extends State<AccountUiPage> {\n  late Future<ProfileCapabilities?> _profileFuture;\n''',
    '''class _AccountUiPageState extends State<AccountUiPage> {\n  late Future<ProfileCapabilities?> _profileFuture;\n  bool _isSigningOut = false;\n''',
)

replace_once(
    "app/lib/pages/account_page.dart",
    '''                            onPressed: () async {\n                              await AuthService.instance.signOut();\n                              if (context.mounted) {\n                                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);\n                              }\n                            },\n                            icon: const Icon(Icons.logout_rounded),\n                            label: Text(AppLocalizations.of(context)!.disconnect),\n''',
    '''                            onPressed: _isSigningOut\n                                ? null\n                                : () async {\n                                    setState(() => _isSigningOut = true);\n                                    try {\n                                      await AuthService.instance.signOut();\n                                      // Le StreamBuilder du shell remplace\n                                      // automatiquement le profil par LoginPage.\n                                    } catch (error) {\n                                      if (!context.mounted) return;\n                                      ScaffoldMessenger.of(context).showSnackBar(\n                                        SnackBar(\n                                          content: Text(\n                                            'Déconnexion impossible : $error',\n                                          ),\n                                          backgroundColor: Colors.red,\n                                        ),\n                                      );\n                                    } finally {\n                                      if (mounted) {\n                                        setState(() => _isSigningOut = false);\n                                      }\n                                    }\n                                  },\n                            icon: _isSigningOut\n                                ? const SizedBox.square(\n                                    dimension: 18,\n                                    child: CircularProgressIndicator(\n                                      strokeWidth: 2,\n                                      color: Colors.white,\n                                    ),\n                                  )\n                                : const Icon(Icons.logout_rounded),\n                            label: Text(\n                              _isSigningOut\n                                  ? 'Déconnexion...'\n                                  : AppLocalizations.of(context)!.disconnect,\n                            ),\n''',
)

replace_once(
    "app/lib/main.dart",
    "import 'admin/super_admin_space.dart' deferred as adm_super;\n",
    "import 'admin/super_admin_space.dart' deferred as adm_super;\n"
    "import 'admin/superadmin_user_management_page.dart' deferred as adm_user_mgmt;\n",
)

replace_once(
    "app/lib/main.dart",
    '''    case '/login':\n      page = _DeferredLoader(\n        load: user_shell.loadLibrary,\n        build: () => user_shell.UserFacingShellPage(\n          initialTab: <String, dynamic>{'tab': 'profile'},\n        ),\n      );\n      break;\n''',
    '''    case '/login':\n      page = _DeferredLoader(\n        load: user_shell.loadLibrary,\n        build: () => user_shell.UserFacingShellPage(\n          initialTab: <String, dynamic>{'tab': 'profile'},\n        ),\n      );\n      break;\n    case '/admin/users':\n    case '/admin/group-accounts':\n      final initialRole = name == '/admin/group-accounts' ? 'group' : null;\n      page = _DeferredLoader(\n        load: adm_user_mgmt.loadLibrary,\n        build: () => adm_user_mgmt.SuperAdminUserManagementPage(\n          initialRole: initialRole,\n        ),\n      );\n      break;\n''',
)

replace_once(
    "app/lib/admin/super_admin_space.dart",
    '''            _buildActionCard(\n              'Gérer Utilisateurs',\n              Icons.people_outline,\n              Colors.blue,\n              () => Navigator.pushNamed(context, '/admin/users'),\n            ),\n            _buildActionCard(\n              'Gérer Rôles',\n''',
    '''            _buildActionCard(\n              'Gérer Utilisateurs',\n              Icons.people_outline,\n              Colors.blue,\n              () => Navigator.pushNamed(context, '/admin/users'),\n            ),\n            _buildActionCard(\n              'Admin Groupe & Trackers',\n              Icons.groups_2_outlined,\n              Colors.indigo,\n              () => Navigator.pushNamed(context, '/admin/group-accounts'),\n            ),\n            _buildActionCard(\n              'Gérer Rôles',\n''',
)

replace_once(
    "app/lib/pages/account_admin_page.dart",
    '''                    const SizedBox(height: 20),\n\n                    if (isAdmin && !isMobile) ...[\n''',
    '''                    const SizedBox(height: 20),\n\n                    if (isSuperAdmin) ...[\n                      const _SectionTitle('Gestion SuperAdmin'),\n                      const SizedBox(height: 10),\n                      _SectionCard(\n                        title: 'Admin Groupe & Trackers',\n                        subtitle:\n                            'Créer les comptes, générer QR/code et gérer les rattachements',\n                        icon: Icons.groups_2_rounded,\n                        onTap: () => Navigator.of(context).pushNamed(\n                          '/admin/group-accounts',\n                        ),\n                      ),\n                      const SizedBox(height: 12),\n                      _SectionCard(\n                        title: 'Tous les utilisateurs',\n                        subtitle:\n                            'Rechercher, créer, modifier, désactiver ou supprimer',\n                        icon: Icons.manage_accounts_rounded,\n                        onTap: () => Navigator.of(context).pushNamed(\n                          '/admin/users',\n                        ),\n                      ),\n                      const SizedBox(height: 20),\n                    ],\n\n                    if (isAdmin && !isMobile) ...[\n''',
)

replace_once(
    "app/lib/admin/superadmin_user_management_page.dart",
    '''        _users = initialRole == null\n            ? result.users\n            : result.users.where((user) => user.role == initialRole).toList();\n''',
    '''        _users = initialRole == null\n            ? result.users\n            : result.users\n                .where(\n                  (user) => initialRole == 'group'\n                      ? user.role == 'group' || user.role == 'tracker'\n                      : user.role == initialRole,\n                )\n                .toList();\n''',
)

print("Patch SuperAdmin appliqué avec succès.")
