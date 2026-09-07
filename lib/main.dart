import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AndroidLiquidLauncher());

class AndroidLiquidLauncher extends StatelessWidget {
  const AndroidLiquidLauncher({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Liquid Glass Launcher',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      );
}

class LauncherApp {
  final String name, packageName, className, iconBase64;
  const LauncherApp({required this.name, required this.packageName, required this.className, required this.iconBase64});
  factory LauncherApp.fromMap(Map<dynamic, dynamic> m) => LauncherApp(
        name: m['name'] as String? ?? 'App',
        packageName: m['packageName'] as String? ?? '',
        className: m['className'] as String? ?? '',
        iconBase64: m['icon'] as String? ?? '',
      );
}

class LauncherBridge {
  static const channel = MethodChannel('iphone_launcher/apps');
  static Future<List<LauncherApp>> apps() async {
    try {
      final raw = await channel.invokeMethod<List<dynamic>>('getInstalledApps');
      return (raw ?? []).map((e) => LauncherApp.fromMap(Map<dynamic, dynamic>.from(e as Map))).toList();
    } catch (_) { return []; }
  }
  static Future<bool> launch(LauncherApp app) async {
    try { return await channel.invokeMethod<bool>('launchApp', {'packageName': app.packageName, 'className': app.className}) ?? false; } catch (_) { return false; }
  }
  static Future<bool> isDefaultHome() async => await channel.invokeMethod<bool>('isDefaultHome') ?? false;
  static Future<bool> requestDefaultHome() async => await channel.invokeMethod<bool>('requestDefaultHome') ?? false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final List<LauncherApp> homeApps = [];
  List<LauncherApp> allApps = [];
  String query = '';
  bool drawer = false, search = false, settings = false, defaultHome = false, loading = true;
  late final AnimationController liquid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    liquid = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
    refreshApps();
  }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); liquid.dispose(); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.resumed) refreshApps(); }

  Future<void> refreshApps() async {
    final result = await LauncherBridge.apps();
    if (!mounted) return;
    final valid = result.map((e) => e.packageName).toSet();
    setState(() {
      allApps = result;
      homeApps.removeWhere((e) => !valid.contains(e.packageName));
      for (final app in result) {
        if (homeApps.length >= 20) break;
        if (!homeApps.any((e) => e.packageName == app.packageName)) homeApps.add(app);
      }
      loading = false;
    });
    defaultHome = await LauncherBridge.isDefaultHome();
    if (mounted) setState(() {});
  }

  Future<void> openApp(LauncherApp app) async {
    if (!await LauncherBridge.launch(app) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open ${app.name}')));
    }
  }

  Widget appIcon(LauncherApp app, {double size = 66}) {
    Widget image;
    try {
      image = app.iconBase64.isEmpty
          ? const Icon(CupertinoIcons.app_fill, color: Colors.white, size: 30)
          : Image.memory(base64Decode(app.iconBase64), width: size, height: size, fit: BoxFit.cover);
    } catch (_) { image = const Icon(CupertinoIcons.app_fill, color: Colors.white, size: 30); }
    return Hero(tag: app.packageName, child: ClipRRect(borderRadius: BorderRadius.circular(size * .23), child: image));
  }

  Future<void> appMenu(LauncherApp app) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LiquidGlass(
        radius: 30,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: appIcon(app, size: 48), title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(app.packageName)),
          ListTile(leading: const Icon(CupertinoIcons.arrow_left), title: const Text('Move left'), onTap: () => Navigator.pop(context, 'left')),
          ListTile(leading: const Icon(CupertinoIcons.arrow_right), title: const Text('Move right'), onTap: () => Navigator.pop(context, 'right')),
          ListTile(leading: const Icon(CupertinoIcons.minus_circle), title: const Text('Remove from Home'), onTap: () => Navigator.pop(context, 'remove')),
        ])),
      ),
    );
    if (!mounted || action == null) return;
    final i = homeApps.indexWhere((e) => e.packageName == app.packageName);
    if (i < 0) return;
    setState(() {
      if (action == 'remove') homeApps.removeAt(i);
      if (action == 'left' && i > 0) { final x = homeApps.removeAt(i); homeApps.insert(i - 1, x); }
      if (action == 'right' && i < homeApps.length - 1) { final x = homeApps.removeAt(i); homeApps.insert(i + 1, x); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allApps.where((a) => a.name.toLowerCase().contains(query.toLowerCase())).toList();
    return AnimatedBuilder(
      animation: liquid,
      builder: (_, __) => Scaffold(
        backgroundColor: const Color(0xff030611),
        body: Stack(children: [
          LiquidBackground(progress: liquid.value),
          SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 2), child: Row(children: [
              Text(_time(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const Spacer(),
              const Icon(CupertinoIcons.wifi, size: 16), const SizedBox(width: 9), const Icon(CupertinoIcons.battery_100, size: 21),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 10), child: Row(children: [
              Expanded(child: Text(defaultHome ? 'Home' : 'Launcher', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -.8))),
              IconButton(onPressed: refreshApps, icon: const Icon(CupertinoIcons.refresh)),
              IconButton(onPressed: () => setState(() => settings = true), icon: const Icon(CupertinoIcons.slider_horizontal_3)),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: GestureDetector(onTap: () => setState(() => search = true), child: const LiquidGlass(child: Row(children: [Icon(CupertinoIcons.search, color: Colors.white70), SizedBox(width: 10), Text('Search apps', style: TextStyle(color: Colors.white70, fontSize: 16))])))),
            if (!defaultHome) Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 2), child: LiquidGlassButton(icon: CupertinoIcons.house_fill, label: 'Set as default Home', onTap: () async { await LauncherBridge.requestDefaultHome(); await refreshApps(); })),
            const SizedBox(height: 10),
            Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : _homeGrid()),
            Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 10), child: GestureDetector(onTap: () => setState(() => drawer = true), onVerticalDragEnd: (_) => setState(() => drawer = true), child: const LiquidGlass(child: SizedBox(height: 58, child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.chevron_up), SizedBox(width: 8), Text('App Drawer', style: TextStyle(fontWeight: FontWeight.w700))]))))),
            Container(width: 118, height: 5, margin: const EdgeInsets.only(bottom: 7), decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8))),
          ])),
          if (drawer) _drawer(filtered),
          if (search) _search(filtered),
          if (settings) _settings(),
        ]),
      ),
    );
  }

  Widget _homeGrid() => GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10), itemCount: homeApps.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 18, crossAxisSpacing: 9, childAspectRatio: .76),
        itemBuilder: (_, i) { final app = homeApps[i]; return GestureDetector(onTap: () => openApp(app), onLongPress: () => appMenu(app), child: Column(children: [
          appIcon(app), const SizedBox(height: 7), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
        ])); },
      );

  Widget _drawer(List<LauncherApp> list) => Positioned.fill(child: LiquidGlass(
        radius: 0, color: const Color(0xff071027).withOpacity(.78), sigma: 28,
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 12), child: Row(children: [const Text('All apps', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => drawer = false), icon: const Icon(CupertinoIcons.xmark))])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: LiquidGlass(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'Search installed apps', border: InputBorder.none)))),
          const SizedBox(height: 12),
          Expanded(child: GridView.builder(padding: const EdgeInsets.all(18), itemCount: list.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 20, crossAxisSpacing: 10, childAspectRatio: .76), itemBuilder: (_, i) { final app = list[i]; return GestureDetector(
            onTap: () => openApp(app), onLongPress: () { if (!homeApps.any((x) => x.packageName == app.packageName)) setState(() => homeApps.add(app)); },
            child: Column(children: [appIcon(app), const SizedBox(height: 7), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))]),
          ); }))
        ])),
      ));

  Widget _search(List<LauncherApp> list) => Positioned.fill(child: LiquidGlass(radius: 0, color: const Color(0xff071027).withOpacity(.86), sigma: 30, child: SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Search', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), TextButton(onPressed: () => setState(() => search = false), child: const Text('Done'))])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: LiquidGlass(child: TextField(autofocus: true, onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'Search installed apps', border: InputBorder.none)))),
    Expanded(child: ListView(children: list.map((app) => ListTile(leading: appIcon(app, size: 48), title: Text(app.name), subtitle: Text(app.packageName), onTap: () { setState(() => search = false); openApp(app); })).toList()))
  ]))));

  Widget _settings() => Positioned.fill(child: LiquidGlass(radius: 0, color: const Color(0xff071027).withOpacity(.84), sigma: 28, child: SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 20), child: Row(children: [const Text('Launcher', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => settings = false), icon: const Icon(CupertinoIcons.xmark))])),
    LiquidGlass(margin: const EdgeInsets.symmetric(horizontal: 18), child: Column(children: [
      ListTile(leading: const Icon(CupertinoIcons.house_fill), title: Text(defaultHome ? 'Default Home enabled' : 'Set as default Home'), subtitle: const Text('Use this launcher when you press Home'), onTap: () async { await LauncherBridge.requestDefaultHome(); await refreshApps(); setState(() => settings = false); }),
      const Divider(height: 1),
      ListTile(leading: const Icon(CupertinoIcons.refresh), title: const Text('Refresh installed apps'), onTap: () { setState(() => settings = false); refreshApps(); }),
    ])),
    const Spacer(), const Padding(padding: EdgeInsets.all(24), child: Text('Liquid Glass • Dynamic Android Launcher', style: TextStyle(color: Colors.white54))),
  ]))));

  String _time() { final n = DateTime.now(); final h = n.hour % 12 == 0 ? 12 : n.hour % 12; return '$h:${n.minute.toString().padLeft(2, '0')}'; }
}

class LiquidBackground extends StatelessWidget {
  final double progress;
  const LiquidBackground({super.key, required this.progress});
  @override Widget build(BuildContext context) => CustomPaint(painter: _LiquidPainter(progress), child: const SizedBox.expand());
}

class _LiquidPainter extends CustomPainter {
  final double p;
  _LiquidPainter(this.p);
  @override void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff152d63), Color(0xff050817), Color(0xff090d24)]).createShader(Offset.zero & s));
    final blobs = [
      (Offset(s.width * (.18 + .10 * p), s.height * .20), s.width * .34, const Color(0xff4f8cff)),
      (Offset(s.width * (.86 - .12 * p), s.height * .48), s.width * .40, const Color(0xff9b5cff)),
      (Offset(s.width * (.35 + .16 * p), s.height * .84), s.width * .32, const Color(0xff00c6a7)),
    ];
    for (final b in blobs) c.drawCircle(b.$1, b.$2, Paint()..color = b.$3.withOpacity(.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55));
  }
  @override bool shouldRepaint(covariant _LiquidPainter old) => old.p != p;
}

class LiquidGlass extends StatelessWidget {
  final Widget child; final double radius, sigma; final EdgeInsetsGeometry? margin, padding; final Color? color;
  const LiquidGlass({super.key, required this.child, this.radius = 24, this.sigma = 20, this.margin, this.padding, this.color});
  @override Widget build(BuildContext context) => Container(margin: margin, child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: Container(
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(radius), border: Border.all(color: Colors.white.withOpacity(.20), width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.20), blurRadius: 24, offset: const Offset(0, 10))], gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(.18), Colors.white.withOpacity(.05)])),
    child: child,
  ))));
}

class LiquidGlassButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const LiquidGlassButton({super.key, required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: LiquidGlass(child: SizedBox(height: 48, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 19), const SizedBox(width: 9), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]))));
}
