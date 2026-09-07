import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LauncherApp {
  final String name;
  final String packageName;
  final String className;
  final String icon;

  const LauncherApp({
    required this.name,
    required this.packageName,
    required this.className,
    required this.icon,
  });

  factory LauncherApp.fromMap(Map<dynamic, dynamic> map) {
    return LauncherApp(
      name: map['name'] as String? ?? 'App',
      packageName: map['packageName'] as String? ?? '',
      className: map['className'] as String? ?? '',
      icon: map['icon'] as String? ?? '',
    );
  }
}

class Bridge {
  static const MethodChannel channel = MethodChannel('iphone_launcher/apps');

  static Future<List<LauncherApp>> apps() async {
    try {
      final raw = await channel.invokeMethod<List<dynamic>>('getInstalledApps');
      return (raw ?? <dynamic>[]).map((dynamic item) {
        return LauncherApp.fromMap(Map<dynamic, dynamic>.from(item as Map));
      }).toList();
    } catch (_) {
      return <LauncherApp>[];
    }
  }

  static Future<bool> launch(LauncherApp app) async {
    try {
      return await channel.invokeMethod<bool>('launchApp', {
            'packageName': app.packageName,
            'className': app.className,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDefault() async {
    try {
      return await channel.invokeMethod<bool>('isDefaultHome') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestDefault() async {
    try {
      return await channel.invokeMethod<bool>('requestDefaultHome') ?? false;
    } catch (_) {
      return false;
    }
  }
}

enum IconLook { clear, dark, light, tinted }

class LiquidLauncher extends StatelessWidget {
  const LiquidLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Liquid Glass Launcher',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<LauncherApp> apps = <LauncherApp>[];
  List<List<LauncherApp>> pages = <List<LauncherApp>>[<LauncherApp>[]];
  final Set<int> hiddenPages = <int>{};

  int page = 0;
  String query = '';
  bool drawer = false;
  bool search = false;
  bool settings = false;
  bool control = false;
  bool edit = false;
  bool defaultHome = false;
  bool loading = true;
  bool largeIcons = false;
  bool focus = false;
  IconLook iconLook = IconLook.clear;
  Color tint = const Color(0xff7dd3fc);

  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final PageController pager = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    pager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final result = await Bridge.apps();
    if (!mounted) {
      return;
    }

    final byPackage = <String, LauncherApp>{
      for (final app in result) app.packageName: app,
    };
    final old = pages
        .expand((List<LauncherApp> p) => p)
        .where((LauncherApp app) => byPackage.containsKey(app.packageName))
        .map((LauncherApp app) => byPackage[app.packageName]!)
        .toList();
    final used = old.map((LauncherApp app) => app.packageName).toSet();

    for (final app in result) {
      if (!used.contains(app.packageName)) {
        old.add(app);
      }
    }

    final rebuilt = <List<LauncherApp>>[];
    for (var i = 0; i < old.length; i += 20) {
      rebuilt.add(old.sublist(i, math.min(i + 20, old.length)));
    }

    setState(() {
      apps = result;
      pages = rebuilt.isEmpty ? <List<LauncherApp>>[<LauncherApp>[]] : rebuilt;
      page = math.min(page, pages.length - 1);
      loading = false;
    });

    defaultHome = await Bridge.isDefault();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _open(LauncherApp app) async {
    final opened = await Bridge.launch(app);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${app.name}')),
      );
    }
  }

  void _move(LauncherApp app, int target, int sourcePage) {
    if (sourcePage < 0 || sourcePage >= pages.length) {
      return;
    }
    final source = pages[sourcePage];
    final from = source.indexWhere(
      (LauncherApp item) => item.packageName == app.packageName,
    );
    if (from < 0) {
      return;
    }

    setState(() {
      source.removeAt(from);
      final destination = pages[page];
      final insertAt = math.min(target, destination.length);
      destination.insert(insertAt, app);
    });
  }

  List<LauncherApp> get visibleApps {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) {
      return apps;
    }
    return apps
        .where((LauncherApp app) => app.name.toLowerCase().contains(lower))
        .toList();
  }

  Widget _icon(LauncherApp app, {double size = 62}) {
    final factor = largeIcons ? 1.16 : 1.0;
    size *= factor;

    Widget child;
    try {
      child = app.icon.isEmpty
          ? const Icon(CupertinoIcons.app_fill, size: 30)
          : Image.memory(
              base64Decode(app.icon),
              width: size,
              height: size,
              fit: BoxFit.cover,
            );
    } catch (_) {
      child = const Icon(CupertinoIcons.app_fill, size: 30);
    }

    final Color background;
    switch (iconLook) {
      case IconLook.light:
        background = Colors.white.withValues(alpha: .72);
      case IconLook.dark:
        background = Colors.black.withValues(alpha: .55);
      case IconLook.tinted:
        background = tint.withValues(alpha: .30);
      case IconLook.clear:
        background = Colors.white.withValues(alpha: .12);
    }

    ColorFilter? filter;
    switch (iconLook) {
      case IconLook.clear:
        filter = null;
      case IconLook.tinted:
        filter = ColorFilter.mode(
          tint.withValues(alpha: .34),
          BlendMode.srcATop,
        );
      case IconLook.dark:
        filter = const ColorFilter.mode(Colors.white, BlendMode.modulate);
      case IconLook.light:
        filter = const ColorFilter.mode(Colors.black12, BlendMode.modulate);
    }

    final decorated = ClipRRect(
      borderRadius: BorderRadius.circular(size * .20),
      child: filter == null ? child : ColorFiltered(colorFilter: filter, child: child),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        color: background,
        border: Border.all(color: Colors.white.withValues(alpha: .26)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: .30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: decorated,
    );
  }

  Widget _tile(LauncherApp app, {bool draggable = true}) {
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _icon(app),
        if (!largeIcons) const SizedBox(height: 7),
        if (!largeIcons)
          Text(
            app.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: edit ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
      ],
    );

    if (!draggable) {
      return GestureDetector(onTap: () => _open(app), child: tile);
    }

    return DragTarget<LauncherApp>(
      onWillAcceptWithDetails: (_) => edit,
      onAcceptWithDetails: (details) {
        final target = pages[page].indexOf(app);
        _move(details.data, target < 0 ? pages[page].length : target, page);
      },
      builder: (_, __, ___) {
        return LongPressDraggable<LauncherApp>(
          data: app,
          feedback: Material(
            color: Colors.transparent,
            child: _icon(app, size: 68),
          ),
          childWhenDragging: Opacity(opacity: .2, child: tile),
          child: GestureDetector(
            onTap: () => _open(app),
            onLongPress: () => _appMenu(app),
            child: tile,
          ),
        );
      },
    );
  }

  Future<void> _appMenu(LauncherApp app) async {
    setState(() => edit = true);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Glass(
          margin: const EdgeInsets.all(10),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: _icon(app, size: 48),
                  title: Text(
                    app.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(app.packageName),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.arrow_left),
                  title: const Text('Move left'),
                  onTap: () => Navigator.pop(context, 'left'),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.arrow_right),
                  title: const Text('Move right'),
                  onTap: () => Navigator.pop(context, 'right'),
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.minus_circle),
                  title: const Text('Remove from Home'),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    final list = pages[page];
    final index = list.indexWhere(
      (LauncherApp item) => item.packageName == app.packageName,
    );
    if (index < 0) {
      return;
    }

    setState(() {
      if (action == 'remove') {
        list.removeAt(index);
      } else if (action == 'left' && index > 0) {
        final item = list.removeAt(index);
        list.insert(index - 1, item);
      } else if (action == 'right' && index < list.length - 1) {
        final item = list.removeAt(index);
        list.insert(index + 1, item);
      }
      edit = false;
    });
  }

  void _addPage() {
    setState(() {
      pages.add(<LauncherApp>[]);
      page = pages.length - 1;
    });
    pager.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = visibleApps;

    return Scaffold(
      backgroundColor: const Color(0xff02050d),
      body: Stack(
        children: <Widget>[
          AnimatedBuilder(
            animation: animation,
            builder: (_, __) => LiquidBackground(
              progress: animation.value,
              tint: tint,
              focus: focus,
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
                  child: Row(
                    children: <Widget>[
                      Text(_time(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => control = true),
                        child: const Icon(CupertinoIcons.wifi, size: 16),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(() => control = true),
                        child: const Icon(CupertinoIcons.battery_100, size: 21),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_greeting(), style: const TextStyle(color: Colors.white60)),
                            Text(
                              defaultHome ? 'Liquid Glass Home' : 'Liquid Glass Launcher',
                              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => control = true),
                        icon: const Icon(CupertinoIcons.slider_horizontal_3),
                      ),
                      IconButton(
                        onPressed: () => setState(() => settings = true),
                        icon: const Icon(CupertinoIcons.gear_alt),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: GestureDetector(
                    onTap: () => setState(() => search = true),
                    child: const Glass(
                      child: Row(
                        children: <Widget>[
                          Icon(CupertinoIcons.search, color: Colors.white70),
                          SizedBox(width: 10),
                          Text(
                            'Search apps',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _widgets(),
                if (!defaultHome)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Glass(
                      child: Row(
                        children: <Widget>[
                          const Icon(CupertinoIcons.house_fill, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Make this your default Home',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Bridge.requestDefault();
                              await _refresh();
                            },
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : PageView.builder(
                          controller: pager,
                          itemCount: pages.length,
                          onPageChanged: (index) => setState(() => page = index),
                          itemBuilder: (_, index) {
                            if (hiddenPages.contains(index)) {
                              return const SizedBox.shrink();
                            }
                            return _grid(pages[index]);
                          },
                        ),
                ),
                if (pages.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(pages.length, (index) {
                        return GestureDetector(
                          onTap: () => pager.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: index == page ? .9 : .3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => drawer = true),
                          child: const Glass(
                            child: SizedBox(
                              height: 58,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(CupertinoIcons.square_grid_2x2_fill),
                                  SizedBox(width: 8),
                                  Text('App Library', style: TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _addPage,
                        child: const Glass(
                          width: 58,
                          child: SizedBox(height: 58, child: Icon(CupertinoIcons.add)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 120,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 7),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          if (drawer) _drawer(filtered),
          if (search) _search(filtered),
          if (settings) _settings(),
          if (control) _controlCenter(),
        ],
      ),
    );
  }

  Widget _widgets() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: <Widget>[
          Glass(
            width: 176,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Today', style: TextStyle(color: Colors.white60)),
                Text(_date(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Glass(
            width: 190,
            child: Row(
              children: <Widget>[
                const Icon(CupertinoIcons.square_grid_2x2_fill, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('App Library'),
                    Text('${apps.length} installed', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Glass(
            width: 190,
            child: Row(
              children: <Widget>[
                Icon(focus ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, size: 28),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(focus ? 'Focus mode' : 'Smart Stack'),
                    Text(
                      focus ? 'Launcher dimmed' : 'Ready',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<LauncherApp> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      itemCount: list.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: largeIcons ? 22 : 17,
        crossAxisSpacing: 9,
        childAspectRatio: largeIcons ? .82 : .77,
      ),
      itemBuilder: (_, index) => _tile(list[index]),
    );
  }

  Widget _drawer(List<LauncherApp> list) {
    final groups = <String, List<LauncherApp>>{};
    for (final app in list) {
      groups.putIfAbsent(_category(app.name), () => <LauncherApp>[]).add(app);
    }

    return Positioned.fill(
      child: Glass(
        radius: 0,
        sigma: 30,
        color: const Color(0xff061027).withValues(alpha: .88),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Row(
                  children: <Widget>[
                    const Text('App Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(() => drawer = false),
                      icon: const Icon(CupertinoIcons.xmark),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Glass(
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(CupertinoIcons.search),
                      hintText: 'Search installed apps',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  children: groups.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: entry.value.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 8,
                                childAspectRatio: .76,
                              ),
                              itemBuilder: (_, index) => _tile(entry.value[index], draggable: false),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _category(String name) {
    final value = name.toLowerCase();
    if (value.contains('music') || value.contains('spotify') || value.contains('youtube')) {
      return 'Entertainment';
    }
    if (value.contains('mail') ||
        value.contains('message') ||
        value.contains('whatsapp') ||
        value.contains('telegram')) {
      return 'Social';
    }
    if (value.contains('camera') || value.contains('photo') || value.contains('gallery')) {
      return 'Creativity';
    }
    if (value.contains('bank') || value.contains('finance') || value.contains('pay')) {
      return 'Finance';
    }
    if (value.contains('game')) {
      return 'Games';
    }
    return 'Other';
  }

  Widget _search(List<LauncherApp> list) {
    return Positioned.fill(
      child: Glass(
        radius: 0,
        sigma: 30,
        color: const Color(0xff061027).withValues(alpha: .92),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: <Widget>[
                    const Text('Spotlight', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        search = false;
                        query = '';
                      }),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Glass(
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(CupertinoIcons.search),
                      hintText: 'Search apps',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: list.map((app) {
                    return ListTile(
                      leading: _icon(app, size: 48),
                      title: Text(app.name),
                      subtitle: Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          search = false;
                          query = '';
                        });
                        _open(app);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlCenter() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => control = false),
        child: Container(
          color: Colors.black.withValues(alpha: .18),
          child: Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {},
                child: Glass(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  radius: 34,
                  sigma: 32,
                  color: const Color(0xff17243d).withValues(alpha: .78),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text(
                              'Control Center',
                              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() => control = false),
                              icon: const Icon(CupertinoIcons.xmark),
                            ),
                          ],
                        ),
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.1,
                          children: <Widget>[
                            _control('Wi-Fi', CupertinoIcons.wifi, true),
                            _control('Bluetooth', CupertinoIcons.bluetooth, true),
                            _control(
                              'Focus',
                              CupertinoIcons.moon_fill,
                              focus,
                              () => setState(() => focus = !focus),
                            ),
                            _control(
                              'Appearance',
                              CupertinoIcons.circle_lefthalf_fill,
                              iconLook == IconLook.dark,
                              () => setState(() {
                                iconLook = iconLook == IconLook.dark
                                    ? IconLook.clear
                                    : IconLook.dark;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(child: _slider('Brightness', CupertinoIcons.sun_max_fill)),
                            Expanded(child: _slider('Volume', CupertinoIcons.speaker_2_fill)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _control(String title, IconData icon, bool active, [VoidCallback? tap]) {
    return GestureDetector(
      onTap: tap,
      child: Glass(
        child: Row(
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Icon(
              active ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Glass(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18),
            Text(title, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 5),
            const LinearProgressIndicator(value: .72),
          ],
        ),
      ),
    );
  }

  Widget _settings() {
    return Positioned.fill(
      child: Glass(
        radius: 0,
        sigma: 30,
        color: const Color(0xff061027).withValues(alpha: .94),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'Home Screen',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => settings = false),
                    icon: const Icon(CupertinoIcons.xmark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Glass(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: edit,
                      onChanged: (value) => setState(() => edit = value),
                      title: const Text('Edit Home Screen'),
                      subtitle: const Text('Rearrange apps and pages'),
                    ),
                    SwitchListTile(
                      value: largeIcons,
                      onChanged: (value) => setState(() => largeIcons = value),
                      title: const Text('Large icons'),
                      subtitle: const Text('Enlarge icons and hide labels'),
                    ),
                    SwitchListTile(
                      value: focus,
                      onChanged: (value) => setState(() => focus = value),
                      title: const Text('Focus mode'),
                      subtitle: const Text('Dim the launcher ambience'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Icon appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Glass(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Clear'),
                      selected: iconLook == IconLook.clear,
                      onSelected: (_) => setState(() => iconLook = IconLook.clear),
                    ),
                    ChoiceChip(
                      label: const Text('Light'),
                      selected: iconLook == IconLook.light,
                      onSelected: (_) => setState(() => iconLook = IconLook.light),
                    ),
                    ChoiceChip(
                      label: const Text('Dark'),
                      selected: iconLook == IconLook.dark,
                      onSelected: (_) => setState(() => iconLook = IconLook.dark),
                    ),
                    ChoiceChip(
                      label: const Text('Tinted'),
                      selected: iconLook == IconLook.tinted,
                      onSelected: (_) => setState(() => iconLook = IconLook.tinted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Glass(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(CupertinoIcons.house_fill),
                      title: Text(defaultHome ? 'Default Home enabled' : 'Set as default Home'),
                      onTap: () async {
                        await Bridge.requestDefault();
                        await _refresh();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(CupertinoIcons.add_circled),
                      title: const Text('Add Home page'),
                      onTap: _addPage,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(CupertinoIcons.refresh),
                      title: const Text('Refresh installed apps'),
                      onTap: () {
                        setState(() => settings = false);
                        _refresh();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Pages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ...List<Widget>.generate(pages.length, (index) {
                return SwitchListTile(
                  value: !hiddenPages.contains(index),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        hiddenPages.remove(index);
                      } else {
                        hiddenPages.add(index);
                      }
                    });
                  },
                  title: Text('Home page ${index + 1}'),
                  subtitle: Text('${pages[index].length} apps'),
                );
              }),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'iPhone-inspired Liquid Glass • Android launcher',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _time() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$hour:${now.minute.toString().padLeft(2, '0')}';
  }

  String _date() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

class Glass extends StatelessWidget {
  final Widget child;
  final double? width;
  final double radius;
  final double sigma;
  final EdgeInsetsGeometry margin;
  final Color? color;

  const Glass({
    super.key,
    required this.child,
    this.width,
    this.radius = 24,
    this.sigma = 18,
    this.margin = EdgeInsets.zero,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: .10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: .13),
                  Colors.white.withValues(alpha: .035),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class LiquidBackground extends StatelessWidget {
  final double progress;
  final Color tint;
  final bool focus;

  const LiquidBackground({
    super.key,
    required this.progress,
    required this.tint,
    required this.focus,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LiquidPainter(progress, tint, focus),
      child: const SizedBox.expand(),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double progress;
  final Color tint;
  final bool focus;

  _LiquidPainter(this.progress, this.tint, this.focus);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff02050d),
    );

    final blobs = <Offset>[
      Offset(
        size.width * (.15 + .10 * math.sin(progress * 2 * math.pi)),
        size.height * .20,
      ),
      Offset(
        size.width * (.82 + .08 * math.cos(progress * 2 * math.pi)),
        size.height * .42,
      ),
      Offset(
        size.width * (.45 + .15 * math.sin(progress * 4 * math.pi)),
        size.height * .84,
      ),
    ];
    final radii = <double>[
      size.width * .42,
      size.width * .36,
      size.width * .45,
    ];

    for (var i = 0; i < blobs.length; i++) {
      final color = Color.lerp(tint, Colors.white, i == 1 ? .35 : .05)!
          .withValues(alpha: focus ? .035 : .085);
      final rect = Rect.fromCircle(center: blobs[i], radius: radii[i]);
      canvas.drawCircle(
        blobs[i],
        radii[i],
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color,
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    final sheen = size.width * progress * 1.7 - size.width * .35;
    final sheenRect = Rect.fromLTWH(sheen, 0, size.width * .22, size.height);
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Colors.transparent,
            Colors.white.withValues(alpha: .025),
            Colors.transparent,
          ],
        ).createShader(sheenRect),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tint != tint ||
        oldDelegate.focus != focus;
  }
}
