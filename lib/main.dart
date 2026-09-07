import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const IPhoneLauncher());

class IPhoneLauncher extends StatelessWidget {
  const IPhoneLauncher({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'iPhone Launcher',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomeScreen(),
      );
}

class LauncherApp {
  final String name;
  final String? packageName;
  final IconData icon;
  final Color color;
  const LauncherApp(this.name, this.icon, this.color, {this.packageName});
}

const fallbackApps = <LauncherApp>[
  LauncherApp('Phone', CupertinoIcons.phone_fill, Color(0xff22c55e)),
  LauncherApp('Messages', CupertinoIcons.chat_bubble_fill, Color(0xff34d399)),
  LauncherApp('Camera', CupertinoIcons.camera_fill, Color(0xff334155)),
  LauncherApp('Photos', CupertinoIcons.photo_fill, Color(0xffec4899)),
  LauncherApp('Maps', CupertinoIcons.location_fill, Color(0xff38bdf8)),
  LauncherApp('Music', CupertinoIcons.music_note, Color(0xfff43f5e)),
  LauncherApp('Weather', CupertinoIcons.cloud_sun_fill, Color(0xff0ea5e9)),
  LauncherApp('Clock', CupertinoIcons.clock_fill, Color(0xff111827)),
  LauncherApp('Notes', CupertinoIcons.doc_text_fill, Color(0xffeab308)),
  LauncherApp('Files', CupertinoIcons.folder_fill, Color(0xff3b82f6)),
  LauncherApp('Settings', CupertinoIcons.gear_alt_fill, Color(0xff64748b)),
  LauncherApp('Browser', CupertinoIcons.compass_fill, Color(0xff2563eb)),
];

class LauncherBridge {
  static const _channel = MethodChannel('iphone_launcher/apps');

  static Future<List<LauncherApp>> installedApps() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return fallbackApps;
      return raw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return LauncherApp(
          map['name'] as String? ?? 'App',
          CupertinoIcons.square_grid_2x2_fill,
          const Color(0xff475569),
          packageName: map['packageName'] as String?,
        );
      }).toList();
    } on PlatformException {
      return fallbackApps;
    }
  }

  static Future<bool> launch(String? packageName) async {
    if (packageName == null) return false;
    try {
      return await _channel.invokeMethod<bool>('launchApp', {'packageName': packageName}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool searchOpen = false;
  bool controlOpen = false;
  bool flashlight = false;
  bool wifi = true;
  bool bluetooth = true;
  double brightness = .75;
  double volume = .55;
  List<LauncherApp> installed = fallbackApps;
  bool loadingApps = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final result = await LauncherBridge.installedApps();
    if (!mounted) return;
    setState(() {
      installed = result;
      loadingApps = false;
    });
  }

  Future<void> openApp(LauncherApp app) async {
    final launched = await LauncherBridge.launch(app.packageName);
    if (!mounted || launched) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 300,
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xff0b1025),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('This app could not be launched on this device.'),
          const Spacer(),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final visibleApps = installed.take(20).toList();
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xff14244b), Color(0xff050817)]))),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('9:41', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Row(children: const [Icon(CupertinoIcons.wifi, size: 17), SizedBox(width: 8), Icon(CupertinoIcons.battery_100, size: 21)]),
            ]),
            const SizedBox(height: 28),
            Align(alignment: Alignment.centerLeft, child: Text('Monday, September 7', style: const TextStyle(color: Colors.white60, fontSize: 16))),
            const Align(alignment: Alignment.centerLeft, child: Text('Good evening', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700))),
            const SizedBox(height: 18),
            GestureDetector(onTap: () => setState(() => searchOpen = true), child: glass(const Row(children: [Icon(CupertinoIcons.search, color: Colors.white60), SizedBox(width: 10), Text('Search apps', style: TextStyle(color: Colors.white60, fontSize: 17))]))),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: weatherCard()), const SizedBox(width: 12), Expanded(child: batteryCard())]),
            const SizedBox(height: 20),
            Expanded(child: loadingApps
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleApps.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 8, childAspectRatio: .78),
                    itemBuilder: (_, i) => GestureDetector(onTap: () => openApp(visibleApps[i]), child: Column(children: [
                      Container(width: min(66, size.width * .16), height: min(66, size.width * .16), decoration: BoxDecoration(color: visibleApps[i].color, borderRadius: BorderRadius.circular(19), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))]), child: Icon(visibleApps[i].icon, color: Colors.white, size: 31)),
                      const SizedBox(height: 6), Text(visibleApps[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                    ])),
                  )),
            glass(Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              if (visibleApps.isNotEmpty) dockButton(visibleApps[0]),
              if (visibleApps.length > 1) dockButton(visibleApps[1]),
              if (visibleApps.length > 2) dockButton(visibleApps[2]),
              if (visibleApps.length > 3) dockButton(visibleApps[3]),
            ])),
            const SizedBox(height: 10),
            Container(width: 120, height: 5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          ]),
        )),
        if (searchOpen) searchPanel(),
        if (controlOpen) controlPanel(),
      ]),
    );
  }

  Widget weatherCard() => glass(const SizedBox(height: 112, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Port Harcourt', style: TextStyle(color: Colors.white60)), Spacer(), Row(children: [Text('28°', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)), Spacer(), Icon(CupertinoIcons.cloud_sun_fill, color: Color(0xffffd166), size: 38)]), Text('Partly cloudy', style: TextStyle(color: Colors.white70, fontSize: 13))])));
  Widget batteryCard() => glass(const SizedBox(height: 112, child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Battery', style: TextStyle(color: Colors.white60)), Spacer(), Text('82%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)), SizedBox(height: 8, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(8)), child: LinearProgressIndicator(value: .82, minHeight: 8, color: Color(0xff4ade80), backgroundColor: Colors.white12)))])));
  Widget dockButton(LauncherApp app) => GestureDetector(onTap: () => openApp(app), child: Container(width: 54, height: 54, decoration: BoxDecoration(color: app.color, borderRadius: BorderRadius.circular(16)), child: Icon(app.icon, color: Colors.white, size: 27)));
  Widget glass(Widget child) => ClipRRect(borderRadius: BorderRadius.circular(25), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), border: Border.all(color: Colors.white.withOpacity(.08))), child: child)));

  Widget searchPanel() => Positioned.fill(child: Container(color: const Color(0xff080d20).withOpacity(.98), padding: const EdgeInsets.fromLTRB(22, 65, 22, 25), child: Column(children: [Row(children: [const Text('Search', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)), const Spacer(), TextButton(onPressed: () => setState(() => searchOpen = false), child: const Text('Done'))]), const SizedBox(height: 20), TextField(autofocus: true, decoration: InputDecoration(prefixIcon: const Icon(CupertinoIcons.search), hintText: 'Search installed apps', filled: true, fillColor: Colors.white12, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)), onChanged: (query) => setState(() {})), const SizedBox(height: 20), Expanded(child: ListView(children: installed.map((a) => ListTile(leading: CircleAvatar(backgroundColor: a.color, child: Icon(a.icon, color: Colors.white)), title: Text(a.name), onTap: () { setState(() => searchOpen = false); openApp(a); })).toList()))])));

  Widget controlPanel() => Positioned.fill(child: GestureDetector(onTap: () => setState(() => controlOpen = false), child: Container(color: Colors.black45, alignment: Alignment.topCenter, padding: const EdgeInsets.only(top: 65), child: GestureDetector(onTap: () {}, child: Container(width: double.infinity, margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xff111a35).withOpacity(.97), borderRadius: BorderRadius.circular(32)), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [const Text('Control Center', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)), const Spacer(), IconButton(onPressed: () => setState(() => controlOpen = false), icon: const Icon(CupertinoIcons.xmark))]), GridView.count(shrinkWrap: true, crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.9, children: [toggle('Wi‑Fi', CupertinoIcons.wifi, wifi, () => setState(() => wifi = !wifi)), toggle('Bluetooth', CupertinoIcons.bluetooth, bluetooth, () => setState(() => bluetooth = !bluetooth)), toggle('Flashlight', CupertinoIcons.light_max, flashlight, () => setState(() => flashlight = !flashlight)), toggle('Airplane', CupertinoIcons.airplane, false, () {})]), const SizedBox(height: 12), slider('Brightness', brightness, (v) => setState(() => brightness = v)), slider('Volume', volume, (v) => setState(() => volume = v))])))));
  Widget toggle(String title, IconData icon, bool active, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: active ? const Color(0xff2563eb) : Colors.white10, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon), const SizedBox(width: 10), Text(title)])));
  Widget slider(String title, double value, ValueChanged<double> onChanged) => Row(children: [SizedBox(width: 90, child: Text(title)), Expanded(child: Slider(value: value, onChanged: onChanged))]);
}

double min(double a, double b) => a < b ? a : b;
