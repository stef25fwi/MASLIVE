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
  }

  @override
  void didUpdateWidget(covariant UserFacingShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentTab = _resolveTab(widget.initialTab);
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

  Widget _buildCachedPage(UserFacingBottomBarTab tab) {
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
          return const MediaPhotoShopPage(showBottomBar: false);
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