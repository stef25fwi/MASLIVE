import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/media_marketplace/presentation/pages/photographer_public_storefront_page.dart';
import '../features/media_marketplace/presentation/pages/private_media_gallery_page.dart';
import '../features/shop/pages/media_photo_shop_page.dart';
import 'account_page.dart';
import 'default_map_page.dart';
import 'login_page.dart';
import 'storex_shop_page.dart';
import 'user_facing_bottom_bar.dart';
import 'user_facing_shell_switch.dart';

class UserFacingShellPage extends StatefulWidget {
  const UserFacingShellPage({super.key, this.initialTab});

  final Object? initialTab;

  static bool switchToExistingShell(
    BuildContext context,
    UserFacingBottomBarTab tab,
  ) {
    final state = _UserFacingShellPageState._active;
    if (state == null || !state.mounted) return false;

    final shellRoute = state._route;
    if (shellRoute == null || !shellRoute.isActive) return false;

    final navigator = Navigator.maybeOf(context);
    if (navigator == null || shellRoute.navigator != navigator) return false;

    navigator.popUntil((route) => route == shellRoute);
    state._selectTab(tab);
    return true;
  }

  @override
  State<UserFacingShellPage> createState() => _UserFacingShellPageState();
}

class _UserFacingShellPageState extends State<UserFacingShellPage> {
  static _UserFacingShellPageState? _active;

  ModalRoute<Object?>? _route;

  late UserFacingBottomBarTab _currentTab;
  Map<String, dynamic> _mediaArgs = const <String, dynamic>{};
  final ValueNotifier<int> _homeActionsMenuSignal = ValueNotifier<int>(0);
  final ValueNotifier<int> _homeActionsMenuCloseSignal = ValueNotifier<int>(0);
  final Map<UserFacingBottomBarTab, Widget> _tabCache =
      <UserFacingBottomBarTab, Widget>{};

  final ValueNotifier<bool> _homeMapForegroundVisible = ValueNotifier<bool>(
    true,
  );

  @override
  void initState() {
    super.initState();
    _active = this;
    activeShellTabSwitcher = UserFacingShellPage.switchToExistingShell;
    _currentTab = _resolveTab(widget.initialTab);
    _mediaArgs = _resolveMediaArgs(widget.initialTab);
    _mergeMediaLinkQuery();
    _syncHomeMapForegroundVisible();
  }

  void _mergeMediaLinkQuery() {
    final galleryId = _routeQueryParam('galleryId');
    final access = _routeQueryParam('access');
    final participant = _routeQueryParam('participant');
    if (galleryId == null || access == null) return;
    _currentTab = UserFacingBottomBarTab.media;
    _mediaArgs = <String, dynamic>{
      ..._mediaArgs,
      'galleryId': galleryId,
      'access': access,
      if (participant != null) 'participant': participant,
    };
  }

  String? _routeQueryParam(String key) {
    final direct = Uri.base.queryParameters[key];
    if (direct?.trim().isNotEmpty == true) return direct!.trim();
    final fragment = Uri.base.fragment;
    final index = fragment.indexOf('?');
    if (index == -1 || index == fragment.length - 1) return null;
    try {
      final value = Uri.splitQueryString(fragment.substring(index + 1))[key];
      return value?.trim().isNotEmpty == true ? value!.trim() : null;
    } catch (_) {
      return null;
    }
  }

  void _syncHomeMapForegroundVisible() {
    _homeMapForegroundVisible.value = _isHomeMapVisible;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _selectTab(UserFacingBottomBarTab tab) {
    if (!mounted) return;

    if (tab == UserFacingBottomBarTab.explorer) {
      if (_currentTab == UserFacingBottomBarTab.explorer) return;
      setState(() => _currentTab = UserFacingBottomBarTab.explorer);
      _syncHomeMapForegroundVisible();
      _homeActionsMenuSignal.value++;
      return;
    }

    if (_currentTab == UserFacingBottomBarTab.explorer) {
      _homeActionsMenuCloseSignal.value++;
    }
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
    _syncHomeMapForegroundVisible();
  }

  @override
  void didUpdateWidget(covariant UserFacingShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentTab = _resolveTab(widget.initialTab);
      _mediaArgs = _resolveMediaArgs(widget.initialTab);
      _mergeMediaLinkQuery();
      _tabCache.remove(UserFacingBottomBarTab.media);
      _syncHomeMapForegroundVisible();
      if (_currentTab == UserFacingBottomBarTab.explorer) {
        _homeActionsMenuSignal.value++;
      }
    }
  }

  @override
  void dispose() {
    if (identical(_active, this)) {
      _active = null;
      activeShellTabSwitcher = null;
    }
    _homeActionsMenuSignal.dispose();
    _homeActionsMenuCloseSignal.dispose();
    _homeMapForegroundVisible.dispose();
    super.dispose();
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
    if (raw is int) return raw.clamp(0, 3);
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
    final galleryId = _mediaArgs['galleryId']?.toString().trim();
    final access = _mediaArgs['access']?.toString().trim();
    if (galleryId?.isNotEmpty == true && access?.isNotEmpty == true) {
      return PrivateMediaGalleryPage(
        key: ValueKey<String>('private:$galleryId:$access'),
        galleryId: galleryId!,
        accessToken: access!,
        participantCode: _mediaArgs['participant']?.toString(),
      );
    }

    final photographerId = _mediaArgs['photographerId']?.toString().trim();
    if (photographerId?.isNotEmpty == true) {
      return PhotographerPublicStorefrontPage(
        key: ValueKey<String>('storefront:$photographerId:${_mediaArgs.toString()}'),
        photographerId: photographerId!,
        countryId: _mediaArgs['countryId'] as String?,
        countryName: _mediaArgs['countryName'] as String?,
        eventId: _mediaArgs['eventId'] as String?,
        eventName: _mediaArgs['eventName'] as String?,
        circuitId: _mediaArgs['circuitId'] as String?,
        circuitName: _mediaArgs['circuitName'] as String?,
      );
    }

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

  Widget _buildHomePage() {
    return _tabCache.putIfAbsent(
      UserFacingBottomBarTab.home,
      () => DefaultMapPage(
        showBottomBar: false,
        openActionsMenuOnLoad: _currentTab == UserFacingBottomBarTab.explorer,
        actionsMenuOpenSignal: _homeActionsMenuSignal,
        actionsMenuCloseSignal: _homeActionsMenuCloseSignal,
        mapVisibleListenable: _homeMapForegroundVisible,
      ),
    );
  }

  Widget _buildCachedPage(UserFacingBottomBarTab tab) {
    if (tab == UserFacingBottomBarTab.home) return _buildHomePage();
    if (tab == UserFacingBottomBarTab.media) return _buildMediaPage();

    return _tabCache.putIfAbsent(tab, () {
      switch (tab) {
        case UserFacingBottomBarTab.boutique:
          return const StorexShopPage(
            shopId: 'global',
            groupId: 'MASLIVE',
            showBottomBar: false,
          );
        case UserFacingBottomBarTab.home:
        case UserFacingBottomBarTab.explorer:
          return const SizedBox.shrink();
        case UserFacingBottomBarTab.media:
          return _buildMediaPage();
        case UserFacingBottomBarTab.profile:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildProfilePage(User? user) {
    if (user != null) return const AccountUiPage(showBottomBar: false);
    return LoginPage(
      onLoginSuccess: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildForegroundPage(User? user) {
    switch (_currentTab) {
      case UserFacingBottomBarTab.profile:
        return _buildProfilePage(user);
      case UserFacingBottomBarTab.boutique:
        return _buildCachedPage(UserFacingBottomBarTab.boutique);
      case UserFacingBottomBarTab.media:
        return _buildCachedPage(UserFacingBottomBarTab.media);
      case UserFacingBottomBarTab.home:
      case UserFacingBottomBarTab.explorer:
        return const SizedBox.shrink();
    }
  }

  bool get _isHomeMapVisible =>
      _currentTab == UserFacingBottomBarTab.home ||
      _currentTab == UserFacingBottomBarTab.explorer;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: _buildHomePage()),
              if (!_isHomeMapVisible)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildForegroundPage(snapshot.data),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: UserFacingBottomBar(
            currentTab: _currentTab,
            onExplorerTap: () {
              if (_currentTab == UserFacingBottomBarTab.home) {
                setState(() => _currentTab = UserFacingBottomBarTab.explorer);
                _syncHomeMapForegroundVisible();
                _homeActionsMenuSignal.value++;
                return;
              }

              if (_currentTab == UserFacingBottomBarTab.explorer) {
                setState(() => _currentTab = UserFacingBottomBarTab.home);
                _syncHomeMapForegroundVisible();
                _homeActionsMenuCloseSignal.value++;
                return;
              }

              setState(() => _currentTab = UserFacingBottomBarTab.explorer);
              _syncHomeMapForegroundVisible();
              _homeActionsMenuSignal.value++;
            },
            onTabSelected: _selectTab,
          ),
        );
      },
    );
  }
}
