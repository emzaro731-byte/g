import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AndroidLauncher());

class AndroidLauncher extends StatelessWidget {
  const AndroidLauncher({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Android Launcher',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      );
}

class LauncherApp {
  final String name;
  final String packageName;
  final String className;
  final String iconBase64;
  const LauncherApp({required this.name, required this.packageName, required this.className, required this.iconBase64});

  factory LauncherApp.fromMap(Map<dynamic, dynamic> map) => LauncherApp(
        name: map['name'] as String? ?? 'App',
        packageName: map['packageName'] as String? ?? '',
        className: map['className'] as String? ?? '',
        iconBase64: map['icon'] as String? ?? '',
      );
}

class LauncherBridge {
  static const channel = MethodChannel('iphone_launcher/apps');

  static Future<List<LauncherApp>> getApps() async {
    try {
      final raw = await channel.invokeMethod<List<dynamic>>('getInstalledApps');
      return (raw ?? []).map((e) => LauncherApp.fromMap(Map<dynamic, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> launch(LauncherApp app) async {
    try {
      return await channel.invokeMethod<bool>('launchApp', {'packageName': app.packageName, 'className': app.className}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDefaultHome() async => await channel.invokeMethod<bool>('isDefaultHome') ?? false;
  static Future<bool> requestDefaultHome() async => await channel.invokeMethod<bool>('requestDefaultHome') ?? false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<LauncherApp> apps = [];
  List<LauncherApp> homeApps = [];
  bool drawerOpen = false;
  bool searchOpen = false;
  bool controlOpen = false;
  bool defaultHome = false;
  String search = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final result = await LauncherBridge.getApps();
    if (!mounted) return;
    final installedPackages = result.map((e) => e.packageName).toSet();
    setState(() {
      apps = result;
      homeApps = homeApps.where((e) => installedPackages.contains(e.packageName)).toList();
      for (final app in result) {
        if (homeApps.length >= 16) break;
        if (!homeApps.any((e) => e.packageName == app.packageName)) homeApps.add(app);
      }
      loading = false;
    });
    defaultHome = await LauncherBridge.isDefaultHome();
    if (mounted) setState(() {});
  }

  Future<void> _open(LauncherApp app) async {
    final ok = await LauncherBridge.launch(app);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${app.name}')));
    }
  }

  Future<void> _longPress(LauncherApp app) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff11182e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: _icon(app, 48), title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w700))),
        ListTile(leading: const Icon(CupertinoIcons.arrow_left), title: const Text('Move left'), onTap: () => Navigator.pop(context, 'left')),
        ListTile(leading: const Icon(CupertinoIcons.arrow_right), title: const Text('Move right'), onTap: () => Navigator.pop(context, 'right')),
        ListTile(leading: const Icon(CupertinoIcons.minus_circle), title: const Text('Remove from Home'), onTap: () => Navigator.pop(context, 'remove')),
        ListTile(leading: const Icon(CupertinoIcons.info_circle), title: const Text('App details'), onTap: () => Navigator.pop(context, 'details')),
      ])),
    );
    if (!mounted || action == null) return;
    final index = homeApps.indexWhere((e) => e.packageName == app.packageName);
    if (index < 0) return;
    setState(() {
      if (action == 'remove') homeApps.removeAt(index);
      if (action == 'left' && index > 0) {
        final item = homeApps.removeAt(index);
        homeApps.insert(index - 1, item);
      }
      if (action == 'right' && index < homeApps.length - 1) {
        final item = homeApps.removeAt(index);
        homeApps.insert(index + 1, item);
      }
    });
    if (action == 'details') _showDetails(app);
  }

  void _showDetails(LauncherApp app) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(app.name), content: Text(app.packageName), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));

  Widget _icon(LauncherApp app, double size) {
    if (app.iconBase64.isNotEmpty) {
      try {
        return ClipRRect(borderRadius: BorderRadius.circular(size * .22), child: Image.memory(base64Decode(app.iconBase64), width: size, height: size, fit: BoxFit.cover));
      } catch (_) {}
    }
    return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(size * .22)), child: const Icon(CupertinoIcons.app));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = apps.where((a) => a.name.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xff182b58), Color(0xff050817)]))),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 8), child: Row(children: [const Text('9:41', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const Spacer(), IconButton(onPressed: () => setState(() => controlOpen = true), icon: const Icon(CupertinoIcons.slider_horizontal_3)), const Icon(CupertinoIcons.wifi, size: 17), const SizedBox(width: 8), const Icon(CupertinoIcons.battery_100, size: 21)])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Row(children: [Expanded(child: Text(defaultHome ? 'Default Home' : 'Android Launcher', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700))), IconButton(onPressed: _refresh, icon: const Icon(CupertinoIcons.refresh))])),
          Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 14), child: GestureDetector(onTap: () => setState(() => searchOpen = true), child: glass(const Row(children: [Icon(CupertinoIcons.search, color: Colors.white60), SizedBox(width: 10), Text('Search installed apps', style: TextStyle(color: Colors.white60, fontSize: 16))])))),
          if (!defaultHome) Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 12), child: OutlinedButton.icon(onPressed: () async { await LauncherBridge.requestDefaultHome(); await _refresh(); }, icon: const Icon(CupertinoIcons.house_fill), label: const Text('Set as default Home'))),
          Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : homeApps.isEmpty ? const Center(child: Text('Long-press apps in the drawer to add them to Home.')) : _homeGrid()),
          Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 10), child: GestureDetector(onTap: () => setState(() => drawerOpen = true), onVerticalDragEnd: (_) => setState(() => drawerOpen = true), child: glass(const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.chevron_up), SizedBox(width: 8), Text('App Drawer', style: TextStyle(fontWeight: FontWeight.w600))]))))),
          Container(width: 120, height: 5, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
        ])),
        if (drawerOpen) _drawer(filtered),
        if (searchOpen) _search(filtered),
        if (controlOpen) _controls(),
      ]),
    );
  }

  Widget _homeGrid() => GridView.builder(padding: const EdgeInsets.fromLTRB(18, 4, 18, 8), itemCount: homeApps.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 18, crossAxisSpacing: 10, childAspectRatio: .78), itemBuilder: (_, i) {
        final app = homeApps[i];
        return GestureDetector(onTap: () => _open(app), onLongPress: () => _longPress(app), child: Column(children: [_icon(app, 62), const SizedBox(height: 7), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))]));
      });

  Widget _drawer(List<LauncherApp> list) => Positioned.fill(child: Container(color: const Color(0xff060a18).withOpacity(.98), child: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 12), child: Row(children: [const Text('All apps', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)), const Spacer(), IconButton(onPressed: () => setState(() => drawerOpen = false), icon: const Icon(CupertinoIcons.xmark))])), Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: TextField(onChanged: (v) => setState(() => search = v), decoration: InputDecoration(prefixIcon: const Icon(CupertinoIcons.search), hintText: 'Search apps', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))), const SizedBox(height: 15), Expanded(child: GridView.builder(padding: const EdgeInsets.all(18), itemCount: list.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 20, crossAxisSpacing: 10, childAspectRatio: .76), itemBuilder: (_, i) { final app = list[i]; return GestureDetector(onTap: () => _open(app), onLongPress: () async { if (!homeApps.any((e) => e.packageName == app.packageName)) setState(() => homeApps.add(app)); }, child: Column(children: [_icon(app, 62), const SizedBox(height: 7), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))])); }))]))));

  Widget _search(List<LauncherApp> list) => Positioned.fill(child: Container(color: const Color(0xff060a18).withOpacity(.99), child: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Search', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)), const Spacer(), TextButton(onPressed: () => setState(() => searchOpen = false), child: const Text('Done'))])), Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: TextField(autofocus: true, onChanged: (v) => setState(() => search = v), decoration: InputDecoration(prefixIcon: const Icon(CupertinoIcons.search), hintText: 'Search installed apps', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))), Expanded(child: ListView(children: list.map((app) => ListTile(leading: _icon(app, 46), title: Text(app.name), subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { setState(() => searchOpen = false); _open(app); })).toList()))]))));

  Widget _controls() => Positioned.fill(child: Container(color: Colors.black54, alignment: Alignment.topCenter, padding: const EdgeInsets.only(top: 55), child: Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xff11182e), borderRadius: BorderRadius.circular(30)), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [const Text('Launcher settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)), const Spacer(), IconButton(onPressed: () => setState(() => controlOpen = false), icon: const Icon(CupertinoIcons.xmark))]), ListTile(leading: const Icon(CupertinoIcons.house_fill), title: Text(defaultHome ? 'Default Home is enabled' : 'Set as default Home'), subtitle: const Text('Choose this launcher as your Android Home app'), onTap: () async { await LauncherBridge.requestDefaultHome(); setState(() => controlOpen = false); await _refresh(); }), ListTile(leading: const Icon(CupertinoIcons.refresh), title: const Text('Refresh installed apps'), onTap: () { setState(() => controlOpen = false); _refresh(); }), const Divider(), const Text('Long-press a Home icon to move it left/right, remove it, or view its package details.')]))));

  Widget glass(Widget child) => ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), border: Border.all(color: Colors.white.withOpacity(.08))), child: child)));
}
