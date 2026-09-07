import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const LiquidLauncher());

class LiquidLauncher extends StatelessWidget {
  const LiquidLauncher({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Liquid Glass Launcher',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      );
}

class LauncherApp {
  final String name, packageName, className, icon;
  const LauncherApp({required this.name, required this.packageName, required this.className, required this.icon});
  factory LauncherApp.fromMap(Map<dynamic, dynamic> m) => LauncherApp(
        name: m['name'] as String? ?? 'App',
        packageName: m['packageName'] as String? ?? '',
        className: m['className'] as String? ?? '',
        icon: m['icon'] as String? ?? '',
      );
}

class Bridge {
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
  static Future<bool> isDefault() async => await channel.invokeMethod<bool>('isDefaultHome') ?? false;
  static Future<bool> requestDefault() async => await channel.invokeMethod<bool>('requestDefaultHome') ?? false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<LauncherApp> apps = [];
  List<List<LauncherApp>> pages = [[]];
  int page = 0;
  String query = '';
  bool drawer = false, search = false, settings = false, edit = false, defaultHome = false, loading = true;
  late final AnimationController animation = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  late final PageController pager = PageController();

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _refresh(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); animation.dispose(); pager.dispose(); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _refresh(); }

  Future<void> _refresh() async {
    final result = await Bridge.apps();
    if (!mounted) return;
    final byPackage = {for (final a in result) a.packageName: a};
    final old = pages.expand((p) => p).where((a) => byPackage.containsKey(a.packageName)).map((a) => byPackage[a.packageName]!).toList();
    final used = old.map((a) => a.packageName).toSet();
    for (final a in result) if (!used.contains(a.packageName)) old.add(a);
    final rebuilt = <List<LauncherApp>>[];
    for (var i = 0; i < old.length; i += 20) rebuilt.add(old.sublist(i, math.min(i + 20, old.length)));
    setState(() { apps = result; pages = rebuilt.isEmpty ? [[]] : rebuilt; page = math.min(page, pages.length - 1); loading = false; });
    defaultHome = await Bridge.isDefault();
    if (mounted) setState(() {});
  }

  Future<void> _open(LauncherApp app) async {
    if (!await Bridge.launch(app) && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${app.name}')));
  }

  void _move(LauncherApp app, int target) {
    final list = pages[page];
    final from = list.indexWhere((a) => a.packageName == app.packageName);
    if (from < 0 || from == target) return;
    setState(() { final item = list.removeAt(from); list.insert(math.min(target, list.length), item); });
  }

  Widget _icon(LauncherApp app, {double size = 62}) {
    Widget child;
    try { child = app.icon.isEmpty ? const Icon(CupertinoIcons.app_fill, size: 30) : Image.memory(base64Decode(app.icon), width: size, height: size, fit: BoxFit.cover); }
    catch (_) { child = const Icon(CupertinoIcons.app_fill, size: 30); }
    return Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .24), color: Colors.white.withOpacity(.10), border: Border.all(color: Colors.white.withOpacity(.22)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 16, offset: const Offset(0, 8))]), child: ClipRRect(borderRadius: BorderRadius.circular(size * .20), child: child));
  }

  Future<void> _appMenu(LauncherApp app) async {
    final action = await showModalBottomSheet<String>(context: context, backgroundColor: Colors.transparent, builder: (_) => Glass(margin: const EdgeInsets.all(10), child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: _icon(app, size: 48), title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(app.packageName)),
      ListTile(leading: const Icon(CupertinoIcons.arrow_left), title: const Text('Move left'), onTap: () => Navigator.pop(context, 'left')),
      ListTile(leading: const Icon(CupertinoIcons.arrow_right), title: const Text('Move right'), onTap: () => Navigator.pop(context, 'right')),
      ListTile(leading: const Icon(CupertinoIcons.minus_circle), title: const Text('Remove from Home'), onTap: () => Navigator.pop(context, 'remove')),
    ]))));
    if (!mounted || action == null) return;
    final list = pages[page];
    final i = list.indexWhere((a) => a.packageName == app.packageName);
    if (i < 0) return;
    setState(() {
      if (action == 'remove') list.removeAt(i);
      if (action == 'left' && i > 0) { final x = list.removeAt(i); list.insert(i - 1, x); }
      if (action == 'right' && i < list.length - 1) { final x = list.removeAt(i); list.insert(i + 1, x); }
      edit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = apps.where((a) => a.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(backgroundColor: const Color(0xff030611), body: Stack(children: [
      AnimatedBuilder(animation: animation, builder: (_, __) => LiquidBackground(progress: animation.value)),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 2), child: Row(children: [Text(_time(), style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), const Icon(CupertinoIcons.wifi, size: 16), const SizedBox(width: 10), const Icon(CupertinoIcons.battery_100, size: 21)])),
        Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 10), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_greeting(), style: const TextStyle(color: Colors.white60)), Text(defaultHome ? 'Liquid Glass Home' : 'Liquid Glass Launcher', style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800))])), IconButton(onPressed: _refresh, icon: const Icon(CupertinoIcons.refresh)), IconButton(onPressed: () => setState(() => settings = true), icon: const Icon(CupertinoIcons.slider_horizontal_3))])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: GestureDetector(onTap: () => setState(() => search = true), child: const Glass(child: Row(children: [Icon(CupertinoIcons.search, color: Colors.white70), SizedBox(width: 10), Text('Search apps', style: TextStyle(color: Colors.white70, fontSize: 16))])))),
        const SizedBox(height: 10),
        _widgets(),
        if (!defaultHome) Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: Glass(child: Row(children: [const Icon(CupertinoIcons.house_fill, size: 18), const SizedBox(width: 10), const Expanded(child: Text('Make this your default Home', maxLines: 1, overflow: TextOverflow.ellipsis)), TextButton(onPressed: () async { await Bridge.requestDefault(); await _refresh(); }, child: const Text('Set'))]))),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : PageView.builder(controller: pager, itemCount: pages.length, onPageChanged: (i) => setState(() => page = i), itemBuilder: (_, i) => _grid(pages[i]))),
        if (pages.length > 1) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == page ? 18 : 6, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(i == page ? .9 : .3), borderRadius: BorderRadius.circular(8))))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 10), child: GestureDetector(onTap: () => setState(() => drawer = true), onVerticalDragEnd: (_) => setState(() => drawer = true), child: const Glass(child: SizedBox(height: 58, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.chevron_up), SizedBox(width: 8), Text('App Library', style: TextStyle(fontWeight: FontWeight.w700))])))),
        Container(width: 120, height: 5, margin: const EdgeInsets.only(bottom: 7), decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8))),
      ])),
      if (drawer) _drawer(filtered),
      if (search) _search(filtered),
      if (settings) _settings(),
    ]));
  }

  Widget _widgets() => SizedBox(height: 86, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [Glass(width: 165, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Today', style: TextStyle(color: Colors.white60)), Text(_date(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))])), const SizedBox(width: 10), Glass(width: 175, child: Row(children: [const Icon(CupertinoIcons.square_grid_2x2_fill, size: 30), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('App Library'), Text('${apps.length} installed', style: const TextStyle(fontWeight: FontWeight.w800))])]))]));

  Widget _grid(List<LauncherApp> list) => GridView.builder(padding: const EdgeInsets.fromLTRB(18, 12, 18, 8), itemCount: list.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 17, crossAxisSpacing: 9, childAspectRatio: .77), itemBuilder: (_, i) { final app = list[i]; return DragTarget<LauncherApp>(onWillAcceptWithDetails: (_) => edit, onAcceptWithDetails: (d) => _move(d.data, i), builder: (_, __, ___) => LongPressDraggable<LauncherApp>(data: app, feedback: Material(color: Colors.transparent, child: _icon(app, size: 68)), childWhenDragging: Opacity(opacity: .25, child: _tile(app)), child: GestureDetector(onTap: () => _open(app), onLongPress: () { setState(() => edit = true); _appMenu(app); }, child: _tile(app)))); });
  Widget _tile(LauncherApp app) => Column(children: [_icon(app), const SizedBox(height: 7), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: edit ? FontWeight.w700 : FontWeight.w500))]);

  Widget _drawer(List<LauncherApp> list) => Positioned.fill(child: Glass(radius: 0, sigma: 28, color: const Color(0xff061027).withOpacity(.84), child: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 12), child: Row(children: [const Text('All apps', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => drawer = false), icon: const Icon(CupertinoIcons.xmark))])), Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Glass(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'Search installed apps', border: InputBorder.none)))), Expanded(child: GridView.builder(padding: const EdgeInsets.all(18), itemCount: list.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 20, crossAxisSpacing: 10, childAspectRatio: .76), itemBuilder: (_, i) { final a = list[i]; return GestureDetector(onTap: () => _open(a), onLongPress: () { if (!pages[page].any((x) => x.packageName == a.packageName)) setState(() => pages[page].add(a)); }, child: _tile(a)); }))]))));

  Widget _search(List<LauncherApp> list) => Positioned.fill(child: Glass(radius: 0, sigma: 28, color: const Color(0xff061027).withOpacity(.88), child: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Search', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), TextButton(onPressed: () => setState(() => search = false), child: const Text('Done'))])), Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Glass(child: TextField(autofocus: true, onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'Search apps', border: InputBorder.none)))), Expanded(child: ListView(children: list.map((a) => ListTile(leading: _icon(a, size: 48), title: Text(a.name), subtitle: Text(a.packageName, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { setState(() => search = false); _open(a); })).toList()))]))));

  Widget _settings() => Positioned.fill(child: Glass(radius: 0, sigma: 28, color: const Color(0xff061027).withOpacity(.86), child: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 20), child: Row(children: [const Text('Launcher controls', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => settings = false), icon: const Icon(CupertinoIcons.xmark))])), Glass(margin: const EdgeInsets.symmetric(horizontal: 18), child: Column(children: [ListTile(leading: const Icon(CupertinoIcons.hand_draw), title: Text(edit ? 'Exit edit mode' : 'Edit Home'), subtitle: const Text('Drag icons to rearrange them'), onTap: () => setState(() { edit = !edit; settings = false; })), const Divider(height: 1), ListTile(leading: const Icon(CupertinoIcons.house_fill), title: Text(defaultHome ? 'Default Home enabled' : 'Set as default Home'), onTap: () async { await Bridge.requestDefault(); await _refresh(); }), const Divider(height: 1), ListTile(leading: const Icon(CupertinoIcons.refresh), title: const Text('Refresh installed apps'), onTap: () { setState(() => settings = false); _refresh(); })])), const Spacer(), const Text('Liquid Glass Android Launcher', style: TextStyle(color: Colors.white38)), const SizedBox(height: 22)]))));

  String _time() { final n = DateTime.now(); final h = n.hour % 12 == 0 ? 12 : n.hour % 12; return '$h:${n.minute.toString().padLeft(2, '0')}'; }
  String _date() { final n = DateTime.now(); return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}'; }
  String _greeting() { final h = DateTime.now().hour; return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'; }
}

class Glass extends StatelessWidget {
  final Widget child; final double radius, sigma, width; final EdgeInsetsGeometry? margin; final Color? color;
  const Glass({super.key, required this.child, this.radius = 24, this.sigma = 20, this.width = double.infinity, this.margin, this.color});
  @override Widget build(BuildContext context) => SizedBox(width: width, child: Container(margin: margin, child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(radius), border: Border.all(color: Colors.white.withOpacity(.20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 25, offset: const Offset(0, 10))], gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(.17), Colors.white.withOpacity(.045)])), child: child)))));
}

class LiquidBackground extends StatelessWidget {
  final double progress;
  const LiquidBackground({super.key, required this.progress});
  @override Widget build(BuildContext context) => CustomPaint(painter: _Painter(progress), child: const SizedBox.expand());
}

class _Painter extends CustomPainter {
  final double p;
  _Painter(this.p);
  @override void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff162f68), Color(0xff040712), Color(0xff071c2b)]).createShader(Offset.zero & s));
    final blobs = [
      (Offset(s.width * (.20 + .11 * math.sin(p * 6.28)), s.height * .18), s.width * .34, const Color(0xff5b8dff)),
      (Offset(s.width * (.82 + .10 * math.cos(p * 6.28)), s.height * .43), s.width * .42, const Color(0xffb25cff)),
      (Offset(s.width * (.38 + .13 * math.sin(p * 4.2)), s.height * .82), s.width * .35, const Color(0xff00d5b2)),
    ];
    for (final b in blobs) c.drawCircle(b.$1, b.$2, Paint()..color = b.$3.withOpacity(.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 58));
  }
  @override bool shouldRepaint(covariant _Painter old) => old.p != p;
}
