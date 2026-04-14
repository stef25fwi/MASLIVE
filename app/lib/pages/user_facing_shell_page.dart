import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/shop/pages/media_photo_shop_page.dart';
import 'account_page.dart';
import 'default_map_page.dart';
import 'login_page.dart';
import 'search_page.dart';
import 'storex_shop_page.dart';
import 'user_facing_bottom_bar.dart';

class UserFacingShellPage extends StatefulWidget {
  const UserFacingShellPage({
    super.key,
    this.initialTab,
  });

  final Object? initialTab;

  @override
  State<UserFacingShellPage> createState() => _UserFacingShellPageState();
}

class _UserFacingShellPageState extends State<UserFacingShellPage> {
  late UserFacingBottomBarTab _currentTab;
  Map<String, dynamic> _mediaArgs = const <String, dynamic>{};
  final Map<UserFacingBottomBarTab, Widget> _tabCache =
      <UserFacingBottomBarTab, Widget>{};

  static const List<UserFacingBottomBarTab> _tabs = <UserFacingBottomBarTab>[
    UserFacingBottomBarTab.profile,
    UserFacingBottomBarTab.boutique,
    UserFacingBottomBarTab.home,
    UserFacingBottomBarTab.media,
    UserFacingBottomBarTab.explorer,
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = _resolveTab(widget.initialTab);
    _mediaArgs = _resolveMediaArgs(widget.initialTab);
  }

  @override
  void didUpdateWidget(covariant UserFacingShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentTab = _resolveTab(widget.initialTab);
      _mediaArgs = _resolveMediaArgs(widget.initialTab);
    }
  }

  UserFacingBottomBarTab _resolveTab(Object? raw) {
    if (raw is UserFacingBottomBarTab) return raw;
    if (raw is String) {
      return UserFacingBottomBarTab.values.firstWhere(
        (tab) => tab.name == raw,
        orElse: () => UserFacingBottomBarTab.home,
      );
    }
    if (raw is Map) {
      return _resolveTab(raw['tab']);
    }
    return UserFacingBottomBarTab.home;
  }

  Map<String, dynamic> _resolveMediaArgs(Object? raw) {
    if (raw is! Map) return const <String, dynamic>{};

    final resolved = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null || key.isEmpty || key == 'tab') continue;
      resolved[key] = entry.value;
    }
    return resolved;
  }

  int? _resolveMediaInitialTabIndex(Object? raw) {
    if (raw is int) {
      return raw.clamp(0, 3);
    }
    if (raw is String) {
      switch (raw) {
        case 'cart':
          return 1;
        case 'downloads':
          return 2;
        case 'photographer':
          return 3;
        default:
          return 0;
      }
    }
    return null;
  }

  Widget _buildMediaPage() {
    return MediaPhotoShopPage(
      key: ValueKey<String>(_mediaArgs.toString()),
      countryId: _mediaArgs['countryId'] as String?,
      countryName: _mediaArgs['countryName'] as String?,
      eventId: _mediaArgs['eventId'] as String?,
      eventName: _mediaArgs['eventName'] as String?,
      circuitId: _mediaArgs['circuitId'] as String?,
      circuitName: _mediaArgs['circuitName'] as String?,
      photographerId: _mediaArgs['photographerId'] as String?,
      ownerUid: _mediaArgs['ownerUid'] as String?,
      initialTabIndex: _resolveMediaInitialTabIndex(_mediaArgs['initialTab']),
      showBottomBar: false,
    );
  }

  Widget _buildCachedPage(UserFacingBottomBarTab tab) {
    if (tab == UserFacingBottomBarTab.media) {
      return _buildMediaPage();
    }

    return _tabCache.putIfAbsent(tab, () {
      switch (tab) {
        case UserFacingBottomBarTab.boutique:
          return const StorexShopPage(
            shopId: 'global',
            groupId: 'MASLIVE',
            showBottomBar: false,
          );
        case UserFacingBottomBarTab.home:
          return const DefaultMapPage(showBottomBar: false);
        case UserFacingBottomBarTab.media:
          return _buildMediaPage();
        case UserFacingBottomBarTab.explorer:
          return const SearchPage(showBottomBar: false);
        case UserFacingBottomBarTab.profile:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildProfilePage(User? user) {
    if (user != null) {
      return const AccountUiPage(showBottomBar: false);
    }
    return LoginPage(
      onLoginSuccess: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final children = <Widget>[
          _buildProfilePage(snapshot.data),
          _buildCachedPage(UserFacingBottomBarTab.boutique),
          _buildCachedPage(UserFacingBottomBarTab.home),
          _buildCachedPage(UserFacingBottomBarTab.media),
          _buildCachedPage(UserFacingBottomBarTab.explorer),
        ];

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: IndexedStack(
            index: _tabs.indexOf(_currentTab),
            children: children,
          ),
          bottomNavigationBar: UserFacingBottomBar(
            currentTab: _currentTab,
            explorerRoute: '/search',
            onTabSelected: (tab) {
              if (tab == _currentTab) return;
              setState(() => _currentTab = tab);
            },
          ),
        );
      },
    );
  }
}