import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static Future<bool> isDefault() async { try { return await channel.invokeMethod<bool>('isDefaultHome') ?? false; } catch (_) { return false; } }
  static Future<bool> requestDefault() async { try { return await channel.invokeMethod<bool>('requestDefaultHome') ?? false; } catch (_) { return false; } }
}

enum IconLook { clear, dark, light, tinted }

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<LauncherApp> apps = [];
  List<List<LauncherApp>> pages = [[]];
  final Set<int> hiddenPages = {};
  int page = 0;
  String query = '';
  bool drawer = false, search = false, settings = false, control = false, edit = false, defaultHome = false, loading = true;
  bool largeIcons = false, tintIcons = false, darkIcons = false, focus = false;
  IconLook iconLook = IconLook.clear;
  Color tint = const Color(0xff7dd3fc);
  late final AnimationController animation = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
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

  void _move(LauncherApp app, int target, int sourcePage) {
    final source = pages[sourcePage];
    final from = source.indexWhere((a) => a.packageName == app.packageName);
    if (from < 0) return;
    setState(() {
      source.removeAt(from);
      if (sourcePage == page) source.insert(math.min(target, source.length), app);
      else pages[page].insert(math.min(target, pages[page].length), app);
    });
  }

  List<LauncherApp> get visibleApps => apps.where((a) => a.name.toLowerCase().contains(query.toLowerCase())).toList();

  Widget _icon(LauncherApp app, {double size = 62}) {
    final factor = largeIcons ? 1.16 : 1.0;
    size *= factor;
    Widget child;
    try { child = app.icon.isEmpty ? const Icon(CupertinoIcons.app_fill, size: 30) : Image.memory(base64Decode(app.icon), width: size, height: size, fit: BoxFit.cover); }
    catch (_) { child = const Icon(CupertinoIcons.app_fill, size: 30); }
    final bg = iconLook == IconLook.light ? Colors.white.withOpacity(.72) : iconLook == IconLook.dark ? Colors.black.withOpacity(.55) : iconLook == IconLook.tinted ? tint.withOpacity(.30) : Colors.white.withOpacity(.12);
    return AnimatedContainer(duration: const Duration(milliseconds: 260), width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .24), color: bg, border: Border.all(color: Colors.white.withOpacity(.26)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.30), blurRadius: 18, offset: const Offset(0, 8))]), child: ClipRRect(borderRadius: BorderRadius.circular(size * .20), child: iconLook == IconLook.clear ? Opacity(opacity: .90, child: child) : ColorFiltered(colorFilter: iconLook == IconLook.tinted ? ColorFilter.mode(tint.withOpacity(.34), BlendMode.srcATop) : iconLook == IconLook.dark ? const ColorFilter.mode(Colors.white, BlendMode.modulate) : const ColorFilter.mode(Colors.black12, BlendMode.modulate), child: child));
  }

  Widget _tile(LauncherApp app, {bool draggable = true}) {
    final tile = Column(children: [_icon(app), const SizedBox(height: 7), Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: largeIcons ? 11 : 12.5, fontWeight: edit ? FontWeight.w800 : FontWeight.w500))]);
    if (!draggable) return GestureDetector(onTap: () => _open(app), child: tile);
    return DragTarget<LauncherApp>(onWillAcceptWithDetails: (_) => edit, onAcceptWithDetails: (d) => _move(d.data, pages[page].indexOf(app), page), builder: (_, __, ___) => LongPressDraggable<LauncherApp>(data: app, feedback: Material(color: Colors.transparent, child: _icon(app, size: 68)), childWhenDragging: Opacity(opacity: .2, child: tile), child: GestureDetector(onTap: () => _open(app), onLongPress: () => _appMenu(app), child: tile)));
  }

  Future<void> _appMenu(LauncherApp app) async {
    setState(() => edit = true);
    final action = await showModalBottomSheet<String>(context: context, backgroundColor: Colors.transparent, builder: (_) => Glass(margin: const EdgeInsets.all(10), child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: _icon(app, size: 48), title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(app.packageName)),
      ListTile(leading: const Icon(CupertinoIcons.folder_badge_plus), title: const Text('Create folder with this app'), onTap: () => Navigator.pop(context, 'folder')),
      ListTile(leading: const Icon(CupertinoIcons.arrow_left), title: const Text('Move left'), onTap: () => Navigator.pop(context, 'left')),
      ListTile(leading: const Icon(CupertinoIcons.arrow_right), title: const Text('Move right'), onTap: () => Navigator.pop(context, 'right')),
      ListTile(leading: const Icon(CupertinoIcons.minus_circle), title: const Text('Remove from Home'), onTap: () => Navigator.pop(context, 'remove')),
    ]))));
    if (!mounted || action == null) return;
    final list = pages[page]; final i = list.indexWhere((a) => a.packageName == app.packageName);
    if (i < 0) return;
    setState(() {
      if (action == 'remove') list.removeAt(i);
      if (action == 'left' && i > 0) { final x = list.removeAt(i); list.insert(i - 1, x); }
      if (action == 'right' && i < list.length - 1) { final x = list.removeAt(i); list.insert(i + 1, x); }
      edit = false;
    });
  }

  void _addPage() { setState(() { pages.add([]); page = pages.length - 1; }); pager.animateToPage(page, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic); }

  @override
  Widget build(BuildContext context) {
    final filtered = visibleApps;
    return Scaffold(backgroundColor: const Color(0xff02050d), body: Stack(children: [
      AnimatedBuilder(animation: animation, builder: (_, __) => LiquidBackground(progress: animation.value, tint: tint, focus: focus)),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 2), child: Row(children: [Text(_time(), style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), GestureDetector(onTap: () => setState(() => control = true), child: const Icon(CupertinoIcons.wifi, size: 16)), const SizedBox(width: 10), GestureDetector(onTap: () => setState(() => control = true), child: const Icon(CupertinoIcons.battery_100, size: 21))])),
        Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 10), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_greeting(), style: const TextStyle(color: Colors.white60)), Text(defaultHome ? 'Liquid Glass Home' : 'Liquid Glass Launcher', style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800))])), IconButton(onPressed: () => setState(() => control = true), icon: const Icon(CupertinoIcons.slider_horizontal_3)), IconButton(onPressed: () => setState(() => settings = true), icon: const Icon(CupertinoIcons.gear_alt))])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: GestureDetector(onTap: () => setState(() => search = true), child: Glass(child: const Row(children: [Icon(CupertinoIcons.search, color: Colors.white70), SizedBox(width: 10), Text('Search apps', style: TextStyle(color: Colors.white70, fontSize: 16))])))),
        const SizedBox(height: 10), _widgets(),
        if (!defaultHome) Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: Glass(child: Row(children: [const Icon(CupertinoIcons.house_fill, size: 18), const SizedBox(width: 10), const Expanded(child: Text('Make this your default Home', maxLines: 1, overflow: TextOverflow.ellipsis)), TextButton(onPressed: () async { await Bridge.requestDefault(); await _refresh(); }, child: const Text('Set'))]))),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : PageView.builder(controller: pager, itemCount: pages.length, onPageChanged: (i) => setState(() => page = i), itemBuilder: (_, i) => hiddenPages.contains(i) ? const SizedBox.shrink() : _grid(pages[i]))),
        if (pages.length > 1) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (i) => GestureDetector(onTap: () => pager.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == page ? 18 : 6, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(i == page ? .9 : .3), borderRadius: BorderRadius.circular(8)))))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 10), child: Row(children: [Expanded(child: GestureDetector(onTap: () => setState(() => drawer = true), child: const Glass(child: SizedBox(height: 58, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(CupertinoIcons.square_grid_2x2_fill), SizedBox(width: 8), Text('App Library', style: TextStyle(fontWeight: FontWeight.w700))])))), const SizedBox(width: 10), GestureDetector(onTap: _addPage, child: const Glass(width: 58, child: SizedBox(height: 58, child: Icon(CupertinoIcons.add))))])),
        Container(width: 120, height: 5, margin: const EdgeInsets.only(bottom: 7), decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8))),
      ])),
      if (drawer) _drawer(filtered), if (search) _search(filtered), if (settings) _settings(), if (control) _controlCenter(),
    ]));
  }

  Widget _widgets() => SizedBox(height: 92, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
        Glass(width: 176, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Today', style: TextStyle(color: Colors.white60)), Text(_date(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))])), const SizedBox(width: 10),
        Glass(width: 190, child: Row(children: [const Icon(CupertinoIcons.square_grid_2x2_fill, size: 30), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [const Text('App Library'), Text('${apps.length} installed', style: TextStyle(fontWeight: FontWeight.w800))])])), const SizedBox(width: 10),
        Glass(width: 190, child: Row(children: [Icon(focus ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, size: 28), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(focus ? 'Focus mode' : 'Smart Stack'), Text(focus ? 'Notifications dimmed' : 'Ready', style: const TextStyle(color: Colors.white60))])]))
      ]));

  Widget _grid(List<LauncherApp> list) => GridView.builder(padding: const EdgeInsets.fromLTRB(18, 12, 18, 8), itemCount: list.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: largeIcons ? 22 : 17, crossAxisSpacing: 9, childAspectRatio: largeIcons ? .82 : .77), itemBuilder: (_, i) => _tile(list[i]));

  Widget _drawer(List<LauncherApp> list) {
    final groups = <String, List<LauncherApp>>{};
    for (final a in list) groups.putIfAbsent(_category(a.name), () => []).add(a);
    return Positioned.fill(child: Glass(radius: 0, sigma: 30, color: const Color(0xff061027).withOpacity(.88), child: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 12), child: Row(children: [const Text('App Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => drawer = false), icon: const Icon(CupertinoIcons.xmark))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Glass(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'Search installed apps', border: InputBorder.none)))),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 30), children: groups.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 8), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800))), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: e.value.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 8, childAspectRatio: .76), itemBuilder: (_, i) => _tile(e.value[i], draggable: false))])))).toList()))
    ]))));
  }

  String _category(String n) { final s = n.toLowerCase(); if (s.contains('music') || s.contains('spotify') || s.contains('youtube')) return 'Entertainment'; if (s.contains('mail') || s.contains('message') || s.contains('whatsapp') || s.contains('telegram')) return 'Social'; if (s.contains('camera') || s.contains('photo') || s.contains('gallery')) return 'Creativity'; if (s.contains('bank') || s.contains('finance') || s.contains('pay')) return 'Finance'; if (s.contains('game')) return 'Games'; return 'Other'; }

  Widget _search(List<LauncherApp> list) => Positioned.fill(child: Glass(radius: 0, sigma: 30, color: const Color(0xff061027).withOpacity(.92), child: SafeArea(child: Column(children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Spotlight', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), TextButton(onPressed: () => setState(() { search = false; query = ''; }), child: const Text('Done'))])), Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Glass(child: TextField(autofocus: true, onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'Search apps', border: InputBorder.none)))), Expanded(child: ListView(children: list.map((a) => ListTile(leading: _icon(a, size: 48), title: Text(a.name), subtitle: Text(a.packageName, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { setState(() { search = false; query = ''; }); _open(a); })).toList()))]))));

  Widget _controlCenter() => Positioned.fill(child: GestureDetector(onTap: () => setState(() => control = false), child: Container(color: Colors.black.withOpacity(.18), child: Align(alignment: Alignment.topCenter, child: SafeArea(child: Glass(margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), radius: 34, sigma: 32, color: const Color(0xff17243d).withOpacity(.78), child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [const Text('Control Center', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => control = false), icon: const Icon(CupertinoIcons.xmark))]), GridView.count(shrinkWrap: true, crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.1, children: [
        _control('Wi-Fi', CupertinoIcons.wifi, true), _control('Bluetooth', CupertinoIcons.bluetooth, true), _control('Focus', CupertinoIcons.moon_fill, focus, () => setState(() => focus = !focus)), _control('Appearance', CupertinoIcons.circle_lefthalf_fill, iconLook == IconLook.dark, () => setState(() => iconLook = iconLook == IconLook.dark ? IconLook.clear : IconLook.dark))
      ]), const SizedBox(height: 12), Row(children: [Expanded(child: _slider('Brightness', CupertinoIcons.sun_max_fill)), Expanded(child: _slider('Volume', CupertinoIcons.speaker_2_fill))])])))))));
  Widget _control(String title, IconData icon, bool active, [VoidCallback? tap]) => GestureDetector(onTap: tap, child: Glass(child: Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)), Icon(active ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, size: 18)])));
  Widget _slider(String title, IconData icon) => Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Glass(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18), Text(title, style: const TextStyle(fontSize: 11)), const SizedBox(height: 5), const LinearProgressIndicator(value: .72)])));

  Widget _settings() => Positioned.fill(child: Glass(radius: 0, sigma: 30, color: const Color(0xff061027).withOpacity(.94), child: SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [Row(children: [const Text('Home Screen', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), IconButton(onPressed: () => setState(() => settings = false), icon: const Icon(CupertinoIcons.xmark))]), const SizedBox(height: 10),
    Glass(child: Column(children: [SwitchListTile(value: edit, onChanged: (v) => setState(() => edit = v), title: const Text('Edit Home Screen'), subtitle: const Text('Rearrange apps and pages')), SwitchListTile(value: largeIcons, onChanged: (v) => setState(() => largeIcons = v), title: const Text('Large icons'), subtitle: const Text('Hide labels visually and enlarge icons')), SwitchListTile(value: focus, onChanged: (v) => setState(() => focus = v), title: const Text('Focus mode'), subtitle: const Text('Dim the launcher ambience'))])),
    const SizedBox(height: 14), const Text('Icon appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
    Glass(child: Wrap(spacing: 8, runSpacing: 8, children: [ChoiceChip(label: const Text('Clear'), selected: iconLook == IconLook.clear, onSelected: (_) => setState(() => iconLook = IconLook.clear)), ChoiceChip(label: const Text('Light'), selected: iconLook == IconLook.light, onSelected: (_) => setState(() => iconLook = IconLook.light)), ChoiceChip(label: const Text('Dark'), selected: iconLook == IconLook.dark, onSelected: (_) => setState(() => iconLook = IconLook.dark)), ChoiceChip(label: const Text('Tinted'), selected: iconLook == IconLook.tinted, onSelected: (_) => setState(() => iconLook = IconLook.tinted))])),
    const SizedBox(height: 14), Glass(child: Column(children: [ListTile(leading: const Icon(CupertinoIcons.house_fill), title: Text(defaultHome ? 'Default Home enabled' : 'Set as default Home'), onTap: () async { await Bridge.requestDefault(); await _refresh(); }), const Divider(height: 1), ListTile(leading: const Icon(CupertinoIcons.add_circled), title: const Text('Add Home page'), onTap: _addPage), const Divider(height: 1), ListTile(leading: const Icon(CupertinoIcons.refresh), title: const Text('Refresh installed apps'), onTap: () { setState(() => settings = false); _refresh(); })])),
    const SizedBox(height: 14), const Text('Pages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), ...List.generate(pages.length, (i) => SwitchListTile(value: !hiddenPages.contains(i), onChanged: (v) => setState(() { if (v) hiddenPages.remove(i); else hiddenPages.add(i); }), title: Text('Home page ${i + 1}'), subtitle: Text('${pages[i].length} apps'))), const SizedBox(height: 30), const Center(child: Text('iPhone-inspired Liquid Glass • Android launcher', style: TextStyle(color: Colors.white38)))])));

  String _time() { final n = DateTime.now(); final h = n.hour % 12 == 0 ? 12 : n.hour % 12; return '$h:${n.minute.toString().padLeft(2, '0')}'; }
  String _date() { final n = DateTime.now(); return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}'; }
  String _greeting() { final h = DateTime.now().hour; return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'; }
}

class Glass extends StatelessWidget {
  final Widget child; final double? width; final double radius, sigma; final EdgeInsetsGeometry margin; final Color? color;
  const Glass({super.key, required this.child, this.width, this.radius = 24, this.sigma = 18, this.margin = EdgeInsets.zero, this.color});
  @override Widget build(BuildContext context) => Container(width: width, margin: margin, decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), border: Border.all(color: Colors.white.withOpacity(.18)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.24), blurRadius: 28, offset: const Offset(0, 12))]), child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(.10), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(.13), Colors.white.withOpacity(.035)])), child: child))));
}

class LiquidBackground extends StatelessWidget {
  final double progress; final Color tint; final bool focus;
  const LiquidBackground({super.key, required this.progress, required this.tint, required this.focus});
  @override Widget build(BuildContext context) => CustomPaint(painter: _LiquidPainter(progress, tint, focus), child: const SizedBox.expand());
}

class _LiquidPainter extends CustomPainter {
  final double p; final Color tint; final bool focus;
  _LiquidPainter(this.p, this.tint, this.focus);
  @override void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xff02050d));
    final blobs = [Offset(s.width * (.15 + .10 * math.sin(p * 2 * math.pi)), s.height * .20), Offset(s.width * (.82 + .08 * math.cos(p * 2 * math.pi)), s.height * .42), Offset(s.width * (.45 + .15 * math.sin(p * 4 * math.pi)), s.height * .84)];
    final radii = [s.width * .42, s.width * .36, s.width * .45];
    for (var i = 0; i < blobs.length; i++) {
      final color = Color.lerp(tint, Colors.white, i == 1 ? .35 : .05)!.withOpacity(focus ? .035 : .085);
      c.drawCircle(blobs[i], radii[i], Paint()..shader = RadialGradient(colors: [color, color.withOpacity(0)]).createShader(Rect.fromCircle(center: blobs[i], radius: radii[i])));
    }
    final sheen = s.width * p * 1.7 - s.width * .35;
    c.drawRect(Rect.fromLTWH(sheen, 0, s.width * .22, s.height), Paint()..shader = LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(.025), Colors.transparent]).createShader(Rect.fromLTWH(sheen, 0, s.width * .22, s.height)));
  }
  @override bool shouldRepaint(covariant _LiquidPainter old) => old.p != p || old.tint != tint || old.focus != focus;
}
