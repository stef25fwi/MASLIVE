from pathlib import Path

p = Path('app/lib/pages/user_facing_shell_page.dart')
s = p.read_text()

old_tabs = """  static const List<UserFacingBottomBarTab> _tabs = <UserFacingBottomBarTab>[
    UserFacingBottomBarTab.profile,
    UserFacingBottomBarTab.boutique,
    UserFacingBottomBarTab.home,
    UserFacingBottomBarTab.media,
    UserFacingBottomBarTab.explorer,
  ];

"""
s = s.replace(old_tabs, "", 1)

old_build = """  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final children = <Widget>[
          _buildProfilePage(snapshot.data),
          _buildCachedPage(UserFacingBottomBarTab.boutique),
          _buildHomePage(),
          _buildCachedPage(UserFacingBottomBarTab.media),
          _buildCachedPage(UserFacingBottomBarTab.explorer),
        ];

        final visibleIndex = _currentTab == UserFacingBottomBarTab.explorer
            ? _tabs.indexOf(UserFacingBottomBarTab.home)
            : _tabs.indexOf(_currentTab);

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: IndexedStack(
            index: visibleIndex,
            children: children,
          ),
          bottomNavigationBar: UserFacingBottomBar(
"""
new_build = """  Widget _buildForegroundPage(User? user) {
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
        final homeMap = _buildHomePage();
        final foreground = _buildForegroundPage(snapshot.data);

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // La carte reste montée pour éviter le clignotement WebGL lors des
              // bascules Home / Explorer. Les autres pages masquent simplement la
              // carte avec un fond opaque, sans la détruire.
              Positioned.fill(child: homeMap),
              if (!_isHomeMapVisible)
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: foreground,
                  ),
                ),
            ],
          ),
          bottomNavigationBar: UserFacingBottomBar(
"""
if old_build not in s:
    raise SystemExit('build block not found')
s = s.replace(old_build, new_build, 1)

p.write_text(s)
