import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // JSON parse için ekle
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const Uygulamam());
}

class FieldInfo {
  final String id;
  final String label;
  final String unit;

  FieldInfo({required this.id, required this.label, required this.unit});

  factory FieldInfo.fromJson(Map<String, dynamic> j) {
    return FieldInfo(
      id: j['id'] ?? '',
      label: j['label'] ?? '',
      unit: j['unit'] ?? '',
    );
  }
}

class MenuItem {
  final String id;
  final String label;
  final List<MenuItem> submenus;
  final List<ParamInfo> params;

  MenuItem({
    required this.id,
    required this.label,
    this.submenus = const [],
    this.params = const [],
  });
}

class ParamInfo {
  final String id;
  final String label;
  final String type; // "number" veya "list"
  final String unit; // varsa
  final List<String>? options; // liste tipi için

  ParamInfo({
    required this.id,
    required this.label,
    required this.type,
    this.unit = '',
    this.options,
  });
}

class ParamChange {
  final String id;
  final String value;
  ParamChange(this.id, this.value);
}

class ModernSettingsMenu extends StatefulWidget {
  final List<MenuItem> menus;
  final Map<String, dynamic> currentValues;
  final ValueChanged<ParamChange> onParamChanged;

  const ModernSettingsMenu({
    super.key,
    required this.menus,
    required this.currentValues,
    required this.onParamChanged,
  });

  @override
  State<ModernSettingsMenu> createState() => _ModernSettingsMenuState();
}

class _ModernSettingsMenuState extends State<ModernSettingsMenu> {
  String? _openPanelId;
  String? _expandedParamId; // Şu anda açık dropdown’un parametre id’si
  final Map<String, TextEditingController> _numberControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  @override
  void didUpdateWidget(covariant ModernSettingsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.currentValues.forEach((id, val) {
      if (_numberControllers.containsKey(id)) {
        final ctl = _numberControllers[id]!;
        final fn = _focusNodes.putIfAbsent(id, () => FocusNode());
        final newText = val?.toString() ?? '';
        // sadece focus kaybolmuşsa reset et
        if (!fn.hasFocus && ctl.text != newText) {
          ctl.text = newText;
        }
      }
    });
  }

  Widget _buildStyledSettingTile(ParamInfo p) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final val = widget.currentValues[p.id];
    final isList = p.type == 'list';
    final isNumber = p.type == 'number';

    final focus = _focusNodes.putIfAbsent(p.id, () {
      final fn = FocusNode();
      fn.addListener(() {
        if (!fn.hasFocus) {
          // TextField’den çıktıysa değeri gönder
          final text = _numberControllers[p.id]!.text;
          widget.onParamChanged(ParamChange(p.id, text));
        }
      });
      return fn;
    });

    // Eğer sayı tipi ise controller’ı al (veya yenisini oluştur)
    TextEditingController? numCtrl;
    if (isNumber) {
      numCtrl = _numberControllers.putIfAbsent(
        p.id,
        () => TextEditingController(
          text: widget.currentValues[p.id]?.toString() ?? '',
        ),
      );
    }
    //final focus = _focusNodes.putIfAbsent(p.id, () => FocusNode());
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  p.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // ► Liste tipi: mevcut kodun aynısı
              if (isList)
                GestureDetector(
                  onTap:
                      () => setState(() {
                        _expandedParamId =
                            (_expandedParamId == p.id ? null : p.id);
                      }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          val?.toString() ?? p.options!.first,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expandedParamId == p.id
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

              // ► Sayı tipi: burayı TextField’e çeviriyoruz
              if (isNumber)
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: numCtrl,
                    focusNode: focus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      suffixText: p.unit,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    // artık onChanged veya onSubmitted’e gerek yok
                  ),
                ),

              // ► (Eğer boolean/switch tipi parametre de varsa, onun için de Switch koyabilirsin)
            ],
          ),
        ),

        // ► Liste seçenekleri kısmı (senin kodun)
        if (isList && _expandedParamId == p.id)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children:
                  p.options!
                      .map(
                        (opt) => InkWell(
                          onTap: () {
                            widget.onParamChanged(ParamChange(p.id, opt));
                            setState(() {
                              widget.currentValues[p.id] = opt;
                              _expandedParamId = null;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                if (opt == val)
                                  Icon(Icons.check, color: primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children:
            widget.menus.map((menu) {
              final isOpen = _openPanelId == menu.id;
              return Column(
                children: [
                  // ─── Başlık Kartı ─────────────────────────────
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _openPanelId = isOpen ? null : menu.id;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      constraints: const BoxConstraints(
                        minHeight: 64, // minimum yükseklik
                        maxHeight: 64, // sabit yükseklik
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              menu.label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: isOpen ? 0.25 : 0, // 90° çevir
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.chevron_right,
                              size: 28,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── İçerik (Parametreler + Alt menüler) ─────────────────
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (final p in menu.params)
                            _buildStyledSettingTile(p),
                          for (final sub in menu.submenus)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: ModernSettingsMenu(
                                menus: [sub],
                                currentValues: widget.currentValues,
                                onParamChanged: widget.onParamChanged,
                              ),
                            ),
                        ],
                      ),
                    ),
                    crossFadeState:
                        isOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    // Controller’ları temizle
    for (final c in _numberControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}

typedef AuthCallback =
    Future<bool> Function(BluetoothDevice device, String password);

class DeviceItemWidget extends StatefulWidget {
  final ScanResult result;
  final VoidCallback onConnect;
  final VoidCallback onCancel;
  final Future<bool> Function(String password) onAuthenticate;
  final bool isBusy;

  const DeviceItemWidget({
    Key? key,
    required this.result,
    required this.onConnect,
    required this.onAuthenticate,
    required this.isBusy,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<DeviceItemWidget> createState() => _DeviceItemWidgetState();
}

class _DeviceItemWidgetState extends State<DeviceItemWidget> {
  // ── UI State ───────────────────────────────────────
  bool expanded = false;
  bool showPasswordField = false;
  final TextEditingController passwordController = TextEditingController();
  String statusMessage = "";

  // ── BLE State ──────────────────────────────────────
  BluetoothCharacteristic? _authCharacteristic;
  BluetoothCharacteristic? _commCharacteristic;
  StreamSubscription<List<int>>? _commSubscription;

  @override
  void dispose() {
    passwordController.dispose();
    _commSubscription?.cancel();

    super.dispose();
  }

  /// 1️⃣ Cihaza bağlan ve gerekli karakteristikleri keşfet
  Future<void> _connectToDevice() async {
    try {
      final device = widget.result.device;
      await device.connect();
      final services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase().contains('ffe0')) {
          for (var c in s.characteristics) {
            final cu = c.uuid.toString().toLowerCase();
            if (cu.contains('ffe2')) {
              _authCharacteristic = c;
            } else if (cu.contains('ffe1')) {
              _commCharacteristic = c;
              // Notify'u aç
              await _commCharacteristic!.setNotifyValue(true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('► BLE bağlantı hatası: $e');
    }
  }

  /// 2️⃣ Şifreyi yaz, AUTH_OK / AUTH_FAIL mesajlarını dinle
  Future<bool> _performAuthentication(String pwd) async {
    if (_authCharacteristic == null || _commCharacteristic == null) {
      return false;
    }
    final completer = Completer<bool>();

    // Gelen bildirimleri dinle
    _commSubscription = _commCharacteristic!.lastValueStream.listen((bytes) {
      final msg = utf8.decode(bytes).trim();
      if (msg.contains('AUTH_OK')) completer.complete(true);
      if (msg.contains('AUTH_FAIL')) completer.complete(false);
    });

    // Şifreyi gönder
    await _authCharacteristic!.write(utf8.encode(pwd), withoutResponse: false);

    // Sonucu bekle
    final result = await completer.future;
    await _commSubscription?.cancel();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    const primaryHex = 0xFF1B3F5C;
    const primaryColor = Color(primaryHex); // kolay kullanım
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        // ← Butonları sola hizalamak için
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kart başlığı
          ListTile(
            leading: const Icon(Icons.bluetooth, color: primaryColor, size: 37),
            title: Text(
              widget.result.device.platformName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: const Text("Device Registered"),
            onTap: () {
              setState(() {
                expanded = !expanded;
                if (!expanded) {
                  showPasswordField = false;
                  statusMessage = "";
                }
              });
            },
          ),

          // — Aşama 1: Küçük, sola yaslı Connect butonu —
          if (expanded && !showPasswordField)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    minimumSize: const Size(100, 36),
                  ),
                  onPressed:
                      widget.isBusy
                          ? null
                          : () {
                            widget.onConnect(); // ← parent’ı haberdar et
                            setState(() => showPasswordField = true);
                            _connectToDevice(); // await zorunlu değil
                          },
                  child: const Text("Connect", style: TextStyle(fontSize: 14)),
                ),
              ),
            ),

          // — Aşama 2: Şifre girişi, solu yaslı küçük butonlar —
          if (showPasswordField)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusMessage.isNotEmpty) ...[
                    Text(
                      statusMessage,
                      style: TextStyle(
                        color:
                            statusMessage.contains("Successful")
                                ? Colors.green
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  TextField(
                    controller: passwordController,
                    keyboardType: TextInputType.number,
                    //obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Sadece rakam
                      LengthLimitingTextInputFormatter(4), // En fazla 4 hane
                    ],
                    //maxLength: 4, // Kullanıcıya da gösterir
                    decoration: InputDecoration(
                      hintText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      //suffixIcon: const Icon(Icons.visibility),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(100, 36),
                          ),
                          onPressed:
                              widget.isBusy
                                  ? null
                                  : () async {
                                    final ok = await _performAuthentication(
                                      passwordController.text,
                                    );
                                    setState(() {
                                      statusMessage =
                                          ok
                                              ? 'Login Successful'
                                              : 'Wrong Password. Try Again.';
                                    });
                                    if (ok) {
                                      if (!context.mounted) return;
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ConnectedScreen(
                                                device: widget.result.device,
                                              ),
                                        ),
                                      );
                                    }
                                  },
                          child: const Text(
                            "Connect",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            minimumSize: const Size(100, 36),
                          ),
                          onPressed:
                              widget.isBusy
                                  ? null
                                  : () {
                                    widget.onCancel();
                                    setState(() {
                                      expanded = false;
                                      showPasswordField = false;
                                      statusMessage = "";
                                      passwordController.clear();
                                    });
                                  },
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
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
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 2 saniye bekle, sonra ana ekrana geç
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BleConnectionScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Eğer status bar’ı da açık tutmak istiyorsanız SystemUiOverlayStyle.dark yapabilirsiniz
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SizedBox.expand(
          child: Image.asset(
            'assets/images/Splash - 2.png', // sadece 2. splash
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class Uygulamam extends StatelessWidget {
  const Uygulamam({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryHex = 0xFF1B3F5C; // #1B3F5C
    const primaryColor = Color(primaryHex); // kolay kullanım

    return MaterialApp(
      title: 'Bluetooth Tarama',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ── RENK PALETİ ──────────────────────────────────────────────
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
        // ── METİN & FONT ────────────────────────────────────────────
        fontFamily: 'Nunito',
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        // ── APPBAR ──────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
        ),
        // ── BUTTON ─────────────────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // ── KART & DİĞER BİLEŞENLER ────────────────────────────────
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          surfaceTintColor: primaryColor.withValues(alpha: .05),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: primaryColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: primaryColor,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      //home: const BleConnectionScreen(),
      home: const SplashScreen(),
    );
  }
}

class BleConnectionScreen extends StatelessWidget {
  const BleConnectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1B3F5C);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    const sidePad = 24.0;

    return Scaffold(
      body: Stack(
        children: [
          // tam ekran arkaplan
          Positioned.fill(
            child: Image.asset(
              'assets/images/Splash_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // hafif şeffaf overlay
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.3)),
          ),

          // başlık + alt metin bloğu
          Positioned(
            top: screenH * 0.36, // eskiden %0.32 idi, şimdi biraz daha aşağı
            left: sidePad,
            right: sidePad,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Scan Nearby',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Devices',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                ),

                SizedBox(height: 16),

                Text(
                  'Discover and connect to nearby device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Scan Devices butonu
          Positioned(
            top: screenH * 0.56, // eskiden %0.50 idi, şimdi biraz daha aşağı
            left: sidePad,
            right: sidePad,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Scan Devices'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  List<ScanResult> scanResults = [];

  DeviceIdentifier? _connectingDeviceId; // connect işleminde olan cihaz
  DeviceIdentifier? _connectedDeviceId; // zaten bağlanmış cihaz

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
  }

  Future<void> _checkPermissionsAndScan() async {
    final locGranted = await Permission.location.request().isGranted;
    final scanGranted = await Permission.bluetoothScan.request().isGranted;
    final connectGranted =
        await Permission.bluetoothConnect.request().isGranted;

    if (locGranted && scanGranted && connectGranted) {
      _startScan();
    } else {
      // Widget tree oluştuktan sonra frame callback ile snack bar göster
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gerekli izinler verilmedi!")),
        );
      });
    }
  }

  void _startScan() {
    FlutterBluePlus.stopScan();
    scanResults.clear();
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 4),
      withServices: [Guid("0000ffe0-0000-1000-8000-00805f9b34fb")],
    );
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults =
            results
                .where((r) => r.device.platformName.trim().isNotEmpty)
                .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1B3F5C);
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/mainBackground.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 110),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bluetooth",
                            style: TextStyle(fontSize: 21, color: primaryColor),
                          ),
                          Text(
                            "Available Devices",
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _startScan,
                        icon: const Icon(
                          Icons.refresh,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: ListView.builder(
                    itemCount: scanResults.length,
                    itemBuilder: (ctx, index) {
                      final result = scanResults[index];
                      return DeviceItemWidget(
                        result: result,
                        onConnect: () {
                          setState(
                            () => _connectingDeviceId = result.device.remoteId,
                          );
                        },
                        onCancel: () {
                          setState(() => _connectingDeviceId = null);
                        },
                        onAuthenticate: (password) async {
                          final resultAuth = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AuthScreen(device: result.device),
                            ),
                          );
                          final ok = resultAuth == true;
                          setState(() {
                            _connectingDeviceId = null;
                            if (ok) _connectedDeviceId = result.device.remoteId;
                          });
                          return ok;
                        },
                        isBusy:
                            (_connectingDeviceId != null &&
                                _connectingDeviceId !=
                                    result.device.remoteId) ||
                            (_connectedDeviceId != null &&
                                _connectedDeviceId != result.device.remoteId),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final BluetoothDevice device;
  const AuthScreen({super.key, required this.device});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  BluetoothCharacteristic? authCharacteristic;
  BluetoothCharacteristic? commCharacteristic;
  final TextEditingController codeController = TextEditingController();
  String statusMessage = "Lütfen ekrandaki bağlantı kodunu giriniz.";
  bool isProcessing = false;
  StreamSubscription<List<int>>? commSubscription;
  bool authSuccessful = false;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _initConnection();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _remainingSeconds = 30;
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!authSuccessful) {
        setState(() {
          statusMessage = "Zaman aşımı! Doğrulama başarısız.";
        });
        _cancel();
      }
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _initConnection() async {
    try {
      await widget.device.connect();
      if (!mounted) return;
      List<BluetoothService> services = await widget.device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains("ffe0")) {
          for (BluetoothCharacteristic c in service.characteristics) {
            String charUuid = c.uuid.toString().toLowerCase();
            if (charUuid.contains("ffe2")) {
              authCharacteristic = c;
            } else if (charUuid.contains("ffe1")) {
              commCharacteristic = c;
            }
          }
        }
      }
      if (authCharacteristic == null) {
        setState(() {
          statusMessage = "Lütfen, Bass Instruments Ürününü Seçiniz.";
        });
        return;
      }
      if (commCharacteristic != null) {
        await commCharacteristic!.setNotifyValue(true);
        commSubscription = commCharacteristic!.lastValueStream.listen((data) {
          String notif = String.fromCharCodes(data).trim();
          if (notif.contains("AUTH_OK")) {
            setState(() {
              authSuccessful = true;
              statusMessage = "Doğrulama başarılı!";
            });
            _timeoutTimer?.cancel();
            _countdownTimer?.cancel();
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ConnectedScreen(device: widget.device),
                ),
              );
            });
          } else if (notif.contains("AUTH_FAIL")) {
            setState(() {
              statusMessage = "Doğrulama başarısız!";
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Bağlantı hatası: $e";
      });
    }
  }

  Future<void> _submitCode() async {
    if (authCharacteristic == null) {
      setState(() {
        statusMessage = "Authentication karakteristiği bulunamadı.";
      });
      return;
    }
    String code = codeController.text.trim();
    if (code.length != 4) {
      setState(() {
        statusMessage = "Lütfen 4 haneli kod girin.";
      });
      return;
    }
    setState(() {
      isProcessing = true;
      statusMessage = "Kod gönderiliyor...";
    });
    try {
      await authCharacteristic!.write(code.codeUnits, withoutResponse: false);
      setState(() {
        statusMessage = "Kod gönderildi, doğrulama bekleniyor...";
      });
    } catch (e) {
      setState(() {
        statusMessage = "Kod gönderilemedi: $e";
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _cancel() async {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    try {
      await widget.device.disconnect();
    } catch (e) {
      // Hata yoksayılabilir
    }
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  void dispose() {
    commSubscription?.cancel();
    codeController.dispose();
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      // disable automatic popping so we can run our logic
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // didPop will always be false here because canPop is false
        _cancel(); // your existing async cleanup
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Bağlantı Onayı"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _cancel,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(statusMessage, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 10),
              if (!authSuccessful && _remainingSeconds > 0)
                Text(
                  "Kalan süre: $_remainingSeconds saniye",
                  style: const TextStyle(fontSize: 18, color: Colors.redAccent),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: "4 Haneli Kod"),
              ),
              const SizedBox(height: 20),
              isProcessing
                  ? const CircularProgressIndicator()
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Kırmızı arka plan
                          foregroundColor: Colors.white, // Beyaz metin
                        ),
                        child: const Text("İptal Et"),
                      ),
                      ElevatedButton(
                        onPressed: _submitCode,
                        child: const Text("Gönder"),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectedScreen extends StatefulWidget {
  final BluetoothDevice device;
  const ConnectedScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<ConnectedScreen> createState() => _ConnectedScreenState();
}

class _ConnectedScreenState extends State<ConnectedScreen>
    with WidgetsBindingObserver {
  bool _lifecycleObserverRegistered = false;
  Timer? _backgroundTimer;
  BuildContext? _scaffoldContext;
  int _currentIndex =
      1; // 0: Settings, 1: Home, 2: Info (başlangıçta Home seçili)
  // ── Değişkenler
  BluetoothCharacteristic? commCharacteristic;
  Timer? _holdTimer;
  DateTime? _pressStartTime;
  String _deviceName = "";

  bool _isParamLoaded = false;
  DateTime _lastButtonPress = DateTime.fromMillisecondsSinceEpoch(0);

  // → Info carousel için
  late final PageController _infoPageController;
  late final Timer _infoAutoTimer;

  String _espDeviceName = ""; // ESP32 meta’dan gelecek “device” alanı
  // State’in en üstünde, diğer değişkenlerin yanında:
  final List<String> _menuTitles = ['Settings', 'Home', 'Information'];
  bool _showControlPanel = false;

  bool _disconnectExpanded = false; // ikon mu, tam buton mu?
  Timer? _disconnectTimer; // 3 saniyelik geri dönüş zamanlayıcısı

  // Meta transfer durumu için:
  StreamSubscription<List<int>>? _metaSubscription;
  bool _metaTransferActive = false;
  bool _metaConfirmed = false;
  int _metaTotal = 0;
  final StringBuffer _metaBuffer = StringBuffer();

  // Data transfer durumu için:
  bool _dataTransferActive = false;
  bool _dataConfirmed = false;
  bool _dataHandshakeActive = false; // “Data_start” alındı, onay gönderildi
  final StringBuffer _dataBuffer = StringBuffer();

  // Yeni Karakteristikler
  BluetoothCharacteristic? metaCharacteristic;
  BluetoothCharacteristic? dataCharacteristic;
  BluetoothCharacteristic? parameterCharacteristic;

  // Meta ve Data
  List<FieldInfo> _fields = [];
  //Map<String, dynamic> _values = {};
  bool _isMetaLoaded = false;
  StreamSubscription<List<int>>? _dataSubscription;

  Map<String, dynamic> _paramValues = {}; // Parametre değerleri
  Map<String, dynamic> _sensorValues = {}; // Sensör verileri

  //PARAMETER Transfer durumları için
  StreamSubscription<List<int>>? _paramSubscription;
  List<MenuItem> _settingsMenu = [];

  int _currentInfoPage = 0;

  @override
  void initState() {
    super.initState();

    _deviceName = widget.device.platformName;
    _discoverAllCharacteristics();
    _registerLifecycleObserver();

    // PageController başlat
    _infoPageController = PageController();

    // 3 saniyede bir sayfa değişsin
    _infoAutoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_infoPageController.hasClients) return;
      final nextPage = (_infoPageController.page!.round() + 1) % 3;
      _infoPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _throttledSendCommand(String cmd) {
    final now = DateTime.now();
    if (now.difference(_lastButtonPress) >= const Duration(milliseconds: 200)) {
      _lastButtonPress = now;
      _sendCommand(cmd);
    }
  }

  void _registerLifecycleObserver() {
    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }
  }

  /// 1. menu node’unu, hem alt menüleri hem parametreleriyle recursive olarak parse eder
  MenuItem _parseMenu(Map<String, dynamic> node) {
    final params = <ParamInfo>[];
    final submenus = <MenuItem>[];

    final children = node['children'] as List<dynamic>;
    for (final raw in children) {
      final child = raw as Map<String, dynamic>;
      if (child['type'] == 'param') {
        params.add(
          ParamInfo(
            id: child['id'],
            label: child['label'],
            type: child['paramType'],
            unit: child['unit'] ?? '',
            options:
                child['options'] != null
                    ? List<String>.from(child['options'])
                    : null,
          ),
        );
      } else if (child['type'] == 'menu') {
        submenus.add(_parseMenu(child));
      }
    }

    return MenuItem(
      id: node['id'],
      label: node['label'],
      params: params,
      submenus: submenus,
    );
  }

  void _parseSettings(Map<String, dynamic> json) {
    final raw = json['settings'] as List<dynamic>;
    final menus = raw
        .map((e) => _parseMenu(e as Map<String, dynamic>))
        .toList(growable: false);

    setState(() {
      _settingsMenu = menus;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    // 1) Hemen başta messenger örneğini al
    final messenger =
        _scaffoldContext != null
            ? ScaffoldMessenger.of(_scaffoldContext!)
            : null;

    // 2) Launch işlemi
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

    // 3) await sonrası mounted kontrolü
    if (!success && mounted) {
      messenger?.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  void _startDisconnectCountdown() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _disconnectExpanded = false;
      });
    });
  }

  void _cancelDisconnectCountdown() {
    _disconnectTimer?.cancel();
  }

  @override
  void dispose() {
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _backgroundTimer?.cancel();
    _infoAutoTimer.cancel();
    _infoPageController.dispose();
    _holdTimer?.cancel();
    _dataSubscription?.cancel();
    _metaSubscription?.cancel();
    _paramSubscription?.cancel();
    _disconnectTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // Uygulama arkaplana geçti
      // Uygulama arkaplana geçti: 1 dakika sonra otomatik disconnect
      _backgroundTimer?.cancel();
      _backgroundTimer = Timer(const Duration(minutes: 1), () async {
        try {
          await widget.device.disconnect();
        } catch (_) {}
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      // Kullanıcı geri döndüğünde iptal et
      _backgroundTimer?.cancel();
    }
  }

  Future<void> _onMetaNotify(List<int> bytes) async {
    final msg = utf8.decode(bytes).trim();
    debugPrint("🚀 Meta bildirim alındı: $msg");

    // 1) Başlangıç paketi
    if (msg.startsWith("Meta_start_") && !_metaConfirmed) {
      final parts = msg.split("_");
      final total = int.tryParse(parts.last) ?? 0;
      setState(() {
        _metaTotal = total;
        _metaBuffer.clear();
        _metaTransferActive = true;
        _metaConfirmed = true;
      });
      debugPrint("⏳ Meta transfer başlatıldı: $_metaTotal paket");
      await commCharacteristic?.write(
        utf8.encode("Meta_Confirmed_$_metaTotal"),
        withoutResponse: false,
      );
      debugPrint("✅ Confirmed gönderildi: Meta_Confirmed_$_metaTotal");
      return;
    }

    // 2) Chunk’ları yakala
    if (_metaTransferActive &&
        _metaConfirmed &&
        msg.contains('/') &&
        msg.contains('_')) {
      final parts = msg.split('_');
      final seq = parts[0]; // "3/10"
      final payload = parts.sublist(1).join('_');
      setState(() {
        _metaBuffer.write(payload);
      });
      debugPrint("📦 Parça alındı: $seq");

      final ackCmd = "Meta_ACK_$seq"; // -> "Meta_ACK_3/10"
      await commCharacteristic?.write(
        utf8.encode(ackCmd),
        withoutResponse: false,
      );
      debugPrint("✅ ACK gönderildi: $ackCmd");
      return;
    }

    // 3) Finish
    if (_metaTransferActive && msg == "Meta_finish") {
      debugPrint("🏁 Meta transfer tamamlandı, JSON çözümleniyor…");
      final jsonStr = _metaBuffer.toString().trim();

      // ScaffoldMessenger'u await öncesi alıyoruz
      final messenger = ScaffoldMessenger.of(context);

      try {
        final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
        _parseSettings(obj);
        final metaName = obj["device"] as String? ?? "";
        final fieldsJson = obj["fields"] as List<dynamic>;
        final parsed =
            fieldsJson
                .map((e) => FieldInfo.fromJson(e as Map<String, dynamic>))
                .toList();

        setState(() {
          _fields = parsed;
          _isMetaLoaded = true;
          _espDeviceName = metaName;
          _metaTransferActive = false;
          _metaConfirmed = false;
          _metaTotal = 0;
          _metaBuffer.clear();
        });
        debugPrint(
          "✅ Meta JSON parse edildi, ${_fields.length} alan yüklendi.",
        );

        // Meta_finish bloğu sonunda Data_ready komutunu gönder
        await commCharacteristic?.write(
          utf8.encode("Data_ready"),
          withoutResponse: false,
        );
        debugPrint("🛎️ Data hazır komutu gönderildi: Data_ready");
      } catch (e) {
        debugPrint("❌ Meta JSON parse hatası: $e");
        // async gap sonrası mounted kontrolü
        if (!mounted) return;
        setState(() => _metaTransferActive = false);
        messenger.showSnackBar(
          SnackBar(content: Text("Meta verisi çözümlenemedi: $e")),
        );
      }

      return;
    }
  }

  // ────────────────────────────────────────────────────
  //  BLE keşfi, META okumak, DATA notify vb.
  //  (Aynı mantık, hiç bozmuyoruz)
  // ────────────────────────────────────────────────────

  Future<void> _discoverAllCharacteristics() async {
    try {
      final services = await widget.device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase().contains("ffe0")) {
          for (var c in s.characteristics) {
            final cu = c.uuid.toString().toLowerCase();
            if (cu.contains("ffe1")) {
              commCharacteristic = c;
            } else if (cu.contains("ffe3")) {
              metaCharacteristic = c;
            } else if (cu.contains("ffe4")) {
              dataCharacteristic = c;
            } else if (cu.contains('ffe5')) {
              parameterCharacteristic = c;
            }
          }
        }
      }
      // META
      if (metaCharacteristic != null) {
        await metaCharacteristic!.setNotifyValue(true);
        _metaSubscription = metaCharacteristic!.lastValueStream.listen(
          _onMetaNotify,
        );
        debugPrint("Meta notify aboneliği açıldı");
      }
      // DATA
      if (dataCharacteristic != null) {
        await dataCharacteristic!.setNotifyValue(true);
        _dataSubscription = dataCharacteristic!.lastValueStream.listen(
          _onDataNotify,
        );
      }
      // PARAMETER
      // initState içinde
      if (parameterCharacteristic != null) {
        await parameterCharacteristic!.setNotifyValue(true);
        _paramSubscription = parameterCharacteristic!.lastValueStream.listen(
          _onParamNotify,
        );
        debugPrint("Parameter notify aboneliği açıldı");
      }
      await commCharacteristic?.write(
        utf8.encode("Meta_ready"),
        withoutResponse: false,
      );
      debugPrint("🛎️ Meta hazır komutu gönderildi: Meta_ready");
    } catch (e) {
      debugPrint("discover error: $e");
    }
  }

  // ConnectedScreen içindeki:
  final StringBuffer _paramBuffer = StringBuffer();
  int _paramTotal = 0;
  bool _paramHandshakeActive = false;
  bool _paramConfirmed = false;

  Future<void> _onParamNotify(List<int> bytes) async {
    final msg = utf8.decode(bytes).trim();
    debugPrint("🚀 Param bildirim alındı: $msg");

    // 1) Başlangıç
    if (msg.startsWith("Param_start_") && !_paramConfirmed) {
      _paramTotal = int.tryParse(msg.split("_").last) ?? 0;
      _paramBuffer.clear();
      _paramHandshakeActive = true;
      _paramConfirmed = true;
      // onayı de withoutResponse: true ile yazın
      await parameterCharacteristic!.write(
        utf8.encode("Param_Confirmed_$_paramTotal"),
        withoutResponse: false,
      );
      return;
    }

    // 2) Gerçek “i/j_payload” chunk’ları alın:
    final chunkRe = RegExp(r'^(\d+)\/(\d+)_(.+)$');
    final m = chunkRe.firstMatch(msg);
    if (_paramHandshakeActive && _paramConfirmed && m != null) {
      final seq = m.group(1); // paket numarası (örn "2")
      final total = m.group(2); // toplam paket (örn "3")
      final payload = m.group(3)!; // gerçek JSON parçası
      // buffer’a **sadece** payload’u ekleyin:
      _paramBuffer.write(payload);

      // kendi ACK’inizi yine withoutResponse: true ile yazın
      await parameterCharacteristic!.write(
        utf8.encode("Param_ACK_$seq/$total"),
        withoutResponse: false,
      );
      return;
    }

    // 3) Bitiş mesajı
    if (_paramHandshakeActive && msg == "Param_finish") {
      try {
        final root =
            jsonDecode(_paramBuffer.toString()) as Map<String, dynamic>;
        final params = root['params'] as Map<String, dynamic>;
        setState(() {
          _paramValues = params;
          _isParamLoaded = true;
        });
        debugPrint("✅ Parametreler uygulandı: $_paramValues");
      } catch (e) {
        // …
      }
      _paramHandshakeActive = false;
      _paramConfirmed = false;
      _paramBuffer.clear();
      return;
    }
  }

  Future<void> _onDataNotify(List<int> bytes) async {
    final msg = utf8.decode(bytes).trim();
    //debugPrint("🚀 Data bildirim alındı: $msg");

    // ——————————————————————————
    // 1) Data_start_<total>
    // ——————————————————————————
    if (msg.startsWith("Data_start_")) {
      final parts = msg.split("_");
      final total = int.tryParse(parts.last) ?? 0;
      setState(() {
        _dataBuffer.clear();
        _dataTransferActive = true;
        _dataConfirmed = true;
      });
      // ESP’ye onay-yaz
      _dataHandshakeActive = true;
      await commCharacteristic?.write(
        utf8.encode("Data_Confirmed_$total"),
        withoutResponse: false,
      );
      //debugPrint("✅ Data_confirmed gönderildi: Data_Confirmed_$total");
      return;
    }

    if (_dataHandshakeActive && !_dataConfirmed && msg.contains("/")) {
      // “ACK_…” komutunu bekleyip buna göre _dataConfirmed = true; yapabilirsiniz
      // veya ESP otomatik olarak ikinci aşamayı başlatıyorsa:
      _dataConfirmed = true;
    }
    // ——————————————————————————
    // 2) <seq>/<total>_<payload> chunk’ları
    // ——————————————————————————
    if (_dataConfirmed &&
        _dataTransferActive &&
        msg.contains("/") &&
        msg.contains("_")) {
      final parts = msg.split("_");
      final seq = parts[0]; // e.g. "2/5"
      final payload = parts.sublist(1).join("_");
      setState(() {
        _dataBuffer.write(payload);
      });
      // ACK yaz
      final ack = "Data_ACK_$seq"; // e.g. "Data_ACK_2/5"
      await commCharacteristic?.write(utf8.encode(ack), withoutResponse: false);
      //debugPrint("✅ Data ACK gönderildi: $ack");
      return;
    }

    // ——————————————————————————
    // 3) Data_finish
    // ——————————————————————————
    if (_dataConfirmed && _dataTransferActive && msg == "Data_finish") {
      final jsonStr = _dataBuffer.toString();
      try {
        final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
        final valsMap = obj["values"] as Map<String, dynamic>;
        setState(() {
          _sensorValues = valsMap; // ESKİ _values yerine buraya yaz
          _dataTransferActive = false;
          _dataConfirmed = false;
          _dataHandshakeActive = false;
          _dataBuffer.clear();
        });
        debugPrint("✅ Sensör verisi parse edildi: $_sensorValues");
      } catch (e) {
        debugPrint("❌ Data JSON parse hatası: $e");
        setState(() => _dataTransferActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data verisi çözümlenemedi: $e")),
        );
        setState(() {
          // Sıfırla
          _dataTransferActive = false;
          _dataConfirmed = false;
          _dataHandshakeActive = false;
          _dataConfirmed = false;
          _dataBuffer.clear();
        });
      }
      return;
    }

    // ——————————————————————————
    // (Artık tek parça JSON gelirse eskisi gibi doğrudan parse etme –
    //  çünkü chunk’lı akışa geçtik)
    // ——————————————————————————
  }

  // ────────────────────────────────────────────────────
  //  Komutlar (OK, LEFT, RIGHT, ESC vb.)
  // ────────────────────────────────────────────────────

  Future<void> _sendCommand(String cmd) async {
    if (commCharacteristic != null) {
      await commCharacteristic!.write(cmd.codeUnits, withoutResponse: false);
    }
  }

  void _onPressStart(String direction) {
    _pressStartTime = DateTime.now();
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 2), () {
      _sendCommand("UNLOCK_BTN");
    });
  }

  void _onPressEnd(String direction) {
    final pressDuration = DateTime.now().difference(_pressStartTime!);
    _holdTimer?.cancel();
    if (pressDuration < const Duration(seconds: 2)) {
      if (direction == "LEFT") {
        _throttledSendCommand("LEFT_BTN");
      } else if (direction == "RIGHT") {
        _throttledSendCommand("RIGHT_BTN");
      }
    }
  }

  void _onOkPressed() => _throttledSendCommand("OK_BTN");
  void _onEscPressed() => _throttledSendCommand("ESC_BTN");

  // İsim Değiştirme
  void _showNameChangeDialog() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Yeni Cihaz Adı"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Yeni isim"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  _updateDeviceName(newName);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text("Değiştir"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDeviceName(String newName) async {
    // 1) Messenger’ı await öncesi yakala
    final messenger = ScaffoldMessenger.of(context);

    // 2) Komutu gönder, sonra mounted kontrolü yap
    await _sendCommand("SET_NAME:$newName");
    if (!mounted) return;

    // 3) State’i güncelle ve bildirim göster
    setState(() {
      _deviceName = newName;
    });
    messenger.showSnackBar(
      SnackBar(content: Text("Cihaz ismi '$newName' olarak güncellendi.")),
    );
  }

  Future<void> _disconnectAndPop() async {
    try {
      await widget.device.disconnect();
    } catch (_) {}
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ────────────────────────────────────────────────────
  //  YENI TASARIM (Stack içinde Positioned)
  // ────────────────────────────────────────────────────
  Widget _buildDrawerItem(IconData icon, String title, {bool enabled = true}) {
    return ListTile(
      leading: Icon(icon, color: enabled ? Colors.white : Colors.white54),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          color: enabled ? Colors.white : Colors.white54,
        ),
      ),
      enabled: enabled,
      onTap:
          enabled
              ? () {
                Navigator.of(context).pop(); // menüyü kapatır
              }
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    _scaffoldContext = context;
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      // ① Soldan kayan menü
      drawer: Drawer(
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.9),
                primaryColor.withValues(alpha: 0.3),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // — Üst Kısım: Başlık
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Text(
                    'Bass Instruments',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Divider(
                  color: Colors.white54,
                  thickness: 1,
                  indent: 24,
                  endIndent: 24,
                ),

                // — Menü Öğeleri
                const SizedBox(height: 16),
                _buildDrawerItem(Icons.link_off, 'Disconnect', enabled: false),
                // İleride ekleyeceğiniz başka öğeler için:
                // _buildDrawerItem(Icons.settings, 'Ayarlar'),
                // _buildDrawerItem(Icons.info_outline, 'Bilgi'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ana sayfa arkaplan
          Positioned.fill(
            child: Image.asset(
              'assets/images/mainBackground.png',
              fit: BoxFit.cover,
            ),
          ),
          // ───────── Sol Üst: "Bağlantıyı Kes" ─────────
          // ───────── Klavye ikonunun hemen altı: Bağlantıyı Kes butonu ─────────
          Positioned(
            top: 50,
            right: 80,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  _disconnectExpanded
                      // — Tam genişlemiş buton hali —
                      ? ElevatedButton.icon(
                        key: const ValueKey('full'),
                        icon: const Icon(Icons.link_off, color: Colors.white),
                        label: const Text(
                          "Disconnect",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () {
                          _cancelDisconnectCountdown();
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text("Disconnect"),
                                  content: const Text(
                                    "Are you sure you want to disconnect? This will terminate the connection.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        setState(
                                          () => _disconnectExpanded = false,
                                        );
                                      },
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _disconnectAndPop();
                                      },
                                      child: const Text("Disconnect"),
                                    ),
                                  ],
                                ),
                          );
                        },
                      )
                      // — Sadece ikon hali —
                      : IconButton(
                        key: const ValueKey('icon'),
                        icon: const Icon(
                          Icons.link_off,
                          size: 28,
                          color: Colors.red,
                        ),
                        splashRadius: 24,
                        tooltip: 'Bağlantıyı Kes',
                        onPressed: () {
                          setState(() => _disconnectExpanded = true);
                          _startDisconnectCountdown();
                        },
                      ),
            ),
          ),

          Positioned(
            top: 50, // metnin üstüne gelecek şekilde ayar yine burada
            left: 10,
            child: Builder(
              builder:
                  (context) => IconButton(
                    icon: Icon(
                      Icons.menu,
                      size: 29,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
            ),
          ),
          // ───────── Sağ Üst: Klavye ikonu ─────────
          Positioned(
            top: 50, // ↓ bir miktar daha aşağı
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(1), // dairenin iç boşluğu
              // decoration: BoxDecoration(
              //   color: Colors.white, // beyaz çember
              //   shape: BoxShape.circle,
              //   boxShadow: [
              //     // hafif gölge
              //     BoxShadow(
              //       color: Colors.black26,
              //       blurRadius: 6,
              //       offset: Offset(0, 2),
              //     ),
              //   ],
              // ),
              child: IconButton(
                icon: Icon(Icons.keyboard, size: 24, color: primaryColor),
                onPressed: () {
                  setState(() => _showControlPanel = !_showControlPanel);
                },
              ),
            ),
          ),

          // ───────── Cihaz İsminin Gösteren Metin ─────────
          Positioned(
            top: 115,
            left: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_espDeviceName  |  ',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                GestureDetector(
                  onTap: _showNameChangeDialog,
                  child: Text(
                    _deviceName,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ───────── Menü İsminin Gösteren Metin (Cihaz ismi altında) ─────────
          Positioned(
            top: 140, // ihtiyaç duyduğunuz kadar aşağı kaydırın
            left: 20,
            child: Text(
              _menuTitles[_currentIndex],
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 30, // başlık için büyük punt
                fontWeight: FontWeight.w700, // kalın
                color:
                    Theme.of(context).primaryColor, // uygulamanızın mavi rengi
              ),
            ),
          ),

          // ───────── Ortada: Dinamik Veriler (ListView) ve info ─────────

          // ── 0: Settings İçeriği ──
          if (_currentIndex == 0)
            Positioned(
              top: 200,
              left: 20,
              right: 20,
              bottom: 10,
              child:
                  _isParamLoaded
                      ? ModernSettingsMenu(
                        menus: _settingsMenu,
                        currentValues: _paramValues,
                        onParamChanged: (change) async {
                          // 1) ESP32'ye yaz
                          await parameterCharacteristic?.write(
                            utf8.encode(
                              "Param_SET_${change.id}_${change.value}",
                            ),
                            withoutResponse: false,
                          );
                          // 2) Local state
                          setState(() {
                            _paramValues[change.id] = change.value;
                          });
                        },
                      )
                      : const Center(child: CircularProgressIndicator()),
            ),
          // ── 1: Home İçeriği ──
          if (_currentIndex == 1)
            Positioned(
              top: 30,
              left: 10,
              right: 10,
              bottom: 10,
              child:
                  _isMetaLoaded
                      ? SensorDashboard(
                        values: _sensorValues,
                        unit: _paramValues['units'] as String? ?? 'mbar',
                        showTemperature: _espDeviceName.toLowerCase() == 'msps',
                      )
                      : const Center(child: Text("Veriler yükleniyor…")),
            ),
          // ── 2: Info İçeriği ──
          if (_currentIndex == 2)
            Positioned(
              top: 200, // isteğe bağlı
              left: 20,
              right: 20,
              // height’i büyütüyoruz ki resim + dot + metin sığsın
              height: 510,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1) Carousel (resim alanı)
                  Expanded(
                    child: PageView.builder(
                      controller: _infoPageController,
                      itemCount: 3,
                      onPageChanged:
                          (index) => setState(() => _currentInfoPage = index),
                      itemBuilder:
                          (context, index) => Image.asset(
                            'assets/images/info_foto_${index + 1}.jpg',
                            fit: BoxFit.cover,
                          ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2) Dot göstergeleri
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (idx) {
                      final selected = idx == _currentInfoPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: selected ? 10 : 6,
                        height: selected ? 10 : 6,
                        decoration: BoxDecoration(
                          color:
                              selected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // 3) Altındaki metin
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "Bass Ölçme Enstrümanları Co. Ltd. was founded in Istanbul in 2006 to develop specialized solutions for measuring, monitoring, and controlling fluid parameters such as flow, pressure, level, and temperature.\n\nOur factory, which spans 10,000 m² of open space and 3,500 m² of enclosed area, is home to Turkey’s most advanced and largest liquid and gas flow laboratory.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4) Altındaki ikon + yazı satırı
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Buton
                        _InfoButton(
                          asset: 'assets/images/info_bass_logo.png',
                          label: 'Contact',
                          onTap:
                              () => _launchUrl(
                                'https://www.bass.com.tr/contact/',
                              ),
                        ),

                        // Dikey çizgi
                        VerticalDivider(
                          color: Colors.grey.shade400,
                          thickness: 1,
                        ),

                        // 2. Buton
                        _InfoButton(
                          asset: 'assets/images/info_wp.png',
                          label: 'Support',
                          onTap:
                              () => _launchUrl(
                                'https://api.whatsapp.com/send/?phone=%2B905433418016&text=Bilgi+almak+istiyorum.&type=phone_number&app_absent=0',
                              ),
                        ),

                        VerticalDivider(
                          color: Colors.grey.shade400,
                          thickness: 1,
                        ),

                        // 3. Buton
                        _InfoButton(
                          asset: 'assets/images/info_pdf.png',
                          label: 'Catalog',
                          onTap:
                              () => _launchUrl(
                                'https://www.bass.com.tr/Files/Bass-2025-Catalog.pdf',
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // PANEL AÇIKSA, ARKADAKİYE DOKUNURSA KAPANSIN:
          if (_showControlPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showControlPanel = false),
                behavior: HitTestBehavior.translucent,
                child: Container(), // saydam
              ),
            ),
          // ALTTAKİ BUTON PANELİ:
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: _showControlPanel ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                // yatay boşluk + dikey padding
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ESC + LEFT
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: _onEscPressed,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            "ESC",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Listener(
                          onPointerDown: (_) => _onPressStart("LEFT"),
                          onPointerUp: (_) => _onPressEnd("LEFT"),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () {},
                            child: const Icon(Icons.arrow_left, size: 30),
                          ),
                        ),
                      ],
                    ),
                    // OK + RIGHT
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: _onOkPressed,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            "OK",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Listener(
                          onPointerDown: (_) => _onPressStart("RIGHT"),
                          onPointerUp: (_) => _onPressEnd("RIGHT"),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () {},
                            child: const Icon(Icons.arrow_right, size: 30),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 80,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, Icons.settings_outlined, 'Settings', 0),
              _buildNavItem(context, Icons.home_outlined, 'Home', 1),
              _buildNavItem(context, Icons.info_outlined, 'Info', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final selected = (_currentIndex == index);
    const primaryColor = Color(0xFF1B3F5C);

    return GestureDetector(
      onTap: () async {
        setState(() {
          _currentIndex = index;
          if (index == 0) {
            _isParamLoaded = false;
          }
        });
        if (index == 0) {
          // Parametre akışını başlat:
          await commCharacteristic?.write(
            utf8.encode("Param_ready"),
            withoutResponse: false,
          );
          debugPrint("🛎️ Param_ready gönderildi");
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 5,
            width: 88,
            decoration: BoxDecoration(
              color: selected ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 36, color: selected ? primaryColor : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? primaryColor : Colors.grey,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info sekmesindeki ikon + etiket birleşimi
class _InfoButton extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onTap;

  const _InfoButton({
    required this.asset,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: 40, height: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SensorDashboard extends StatelessWidget {
  final Map<String, dynamic> values;

  const SensorDashboard({
    Key? key,
    required this.values,
    required this.unit,
    this.showTemperature = true,
  }) : super(key: key);

  final bool showTemperature; // ← Yeni alan
  final String unit;

  @override
  Widget build(BuildContext context) {
    final raw = values['main_value'];
    final double mainMbar =
        raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;

    // Birime göre dönüştürme faktörü
    double displayValue;
    switch (unit.toLowerCase()) {
      case 'bar':
        displayValue = mainMbar / 1000.0;
        break;
      case 'pa':
        displayValue = mainMbar * 100.0;
        break;
      case 'kpa':
        displayValue = mainMbar * 0.1;
        break;
      case 'mpa':
        displayValue = mainMbar * 0.0001;
        break;
      case 'kg/cm2':
        displayValue = mainMbar * 0.00101972;
        break;
      case 'mmh2o':
        displayValue = mainMbar * 10.197162;
        break;
      case 'mh2o':
        displayValue = mainMbar * 0.010197162;
        break;
      case 'mmhg':
        displayValue = mainMbar * 0.750062;
        break;
      case 'psi':
        displayValue = mainMbar * 0.0145038;
        break;
      case 'inch water':
        displayValue = mainMbar * 0.401936;
        break;
      case 'mbar':
      default:
        displayValue = mainMbar;
    }

    // Hedef yüze oran değerleri
    final double targetPercent = (values['percent'] ?? 0).toDouble() / 100.0;
    final double sp1 = (values['sp1_percent'] ?? 0).toDouble() / 100.0;
    final double sp2 = (values['sp2_percent'] ?? 0).toDouble() / 100.0;
    //final raw = values['main_value'];
    final double mainNum =
        raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);

        // Çizim parametreleri
        final double strokeWidth = size * 0.12;
        final double backgroundStroke = strokeWidth * 1.2;
        final double markerLength = size * 0.18;
        final double markerThickness = strokeWidth * 0.2;
        final primaryColor = Theme.of(context).primaryColor;
        final bgColor = Colors.grey.shade300;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: targetPercent),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, animatedPercent, _) {
                return Transform.translate(
                  offset: Offset(0, size * 0.33),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(size, size),
                        painter: _DashboardPainter(
                          percent: animatedPercent,
                          sp1: sp1,
                          sp2: sp2,
                          primaryColor: primaryColor,
                          backgroundColor: bgColor,
                          strokeWidth: strokeWidth,
                          backgroundStrokeWidth: backgroundStroke,
                          markerLength: markerLength,
                          markerThickness: markerThickness,
                        ),
                      ),
                      // Yüzde metni
                      Text(
                        "${(animatedPercent * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: size * 0.15,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      // Ana değer (birime göre dönüştürülmüş)
                      Align(
                        alignment: const Alignment(0.0, -2.0),
                        child: Text(
                          displayValue.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: size * 0.22,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      // Alt birim etiketi (dinamik)
                      Align(
                        alignment: const Alignment(0.0, -1.3),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: size * 0.13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),

                      // Sıcaklık
                      // ───────── Sadece MSPS’te gösterilen sıcaklık ─────────
                      if (showTemperature)
                        Align(
                          alignment: const Alignment(0.9, -2.06),
                          child: Text(
                            "${values['temp'] ?? '-'} °C",
                            style: TextStyle(
                              fontSize: size * 0.08,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                        ),
                      // SP1 ve SP2 yüzdeleri
                      Align(
                        alignment: const Alignment(-1.0, 1.1),
                        child: Text(
                          "SP1: ${(values['sp1_percent'] ?? '-')}%",
                          style: TextStyle(
                            fontSize: size * 0.08,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(1.0, 1.1),
                        child: Text(
                          "SP2: ${(values['sp2_percent'] ?? '-')}%",
                          style: TextStyle(
                            fontSize: size * 0.08,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DashboardPainter extends CustomPainter {
  final double percent, sp1, sp2;
  final Color primaryColor, backgroundColor;
  final double strokeWidth, backgroundStrokeWidth;
  final double markerLength, markerThickness;

  const _DashboardPainter({
    required this.percent,
    required this.sp1,
    required this.sp2,
    required this.primaryColor,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.backgroundStrokeWidth,
    required this.markerLength,
    required this.markerThickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        min(size.width, size.height) / 2 * 0.8 -
        max(strokeWidth, backgroundStrokeWidth) / 2 * 0.8;

    // Boş yay
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = backgroundStrokeWidth
          ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      bgPaint,
    );

    // Dolu yay
    final fillPaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      percent * 2 * pi,
      false,
      fillPaint,
    );

    // Marker çizimi
    void drawMarker(double fraction, Color color) {
      final angle = fraction * 2 * pi - pi / 2;
      final half = markerLength / 2;
      final start = Offset(
        center.dx + cos(angle) * (radius - half),
        center.dy + sin(angle) * (radius - half),
      );
      final end = Offset(
        center.dx + cos(angle) * (radius + half),
        center.dy + sin(angle) * (radius + half),
      );
      final mPaint =
          Paint()
            ..color = color
            ..strokeWidth = markerThickness
            ..strokeCap = StrokeCap.butt;
      canvas.drawLine(start, end, mPaint);
    }

    drawMarker(sp1, Colors.blue.shade700);
    drawMarker(sp2, Colors.red.shade700);
  }

  @override
  bool shouldRepaint(covariant _DashboardPainter old) {
    return old.percent != percent || old.sp1 != sp1 || old.sp2 != sp2;
  }
}

/// Basınç değerini, eşiklerin altındaysa SP1 rengiyle,
/// eşikler arasındaysa kendi renginde,
/// aşmışsa SP2 rengiyle saniyede bir kez yanıp söndürür.
class PressureValue extends StatefulWidget {
  final double mainValue; // Mbar olarak gösterilecek değer
  final double percent; // 0.0–1.0 arası mevcut yüzdelik
  final double sp1; // 0.0–1.0 arası SP1 eşiği
  final double sp2; // 0.0–1.0 arası SP2 eşiği
  final double fontSize;
  final Color defaultColor;
  final Color sp1Color;
  final Color sp2Color;

  const PressureValue({
    Key? key,
    required this.mainValue,
    required this.percent,
    required this.sp1,
    required this.sp2,
    required this.fontSize,
    required this.defaultColor,
    required this.sp1Color,
    required this.sp2Color,
  }) : super(key: key);

  @override
  _PressureValueState createState() => _PressureValueState();
}

class _PressureValueState extends State<PressureValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blinkCtrl,
      builder: (_, __) {
        // Öncelikle hangi durumda olduğumuzu belirleyelim:
        final pct = widget.percent;
        Color color;
        if (pct < widget.sp1) {
          // SP1 altındaysa SP1 rengi ↔ default blink
          color =
              _blinkCtrl.value < 0.5 ? widget.sp1Color : widget.defaultColor;
        } else if (pct > widget.sp2) {
          // SP2 üstündeyse SP2 rengi ↔ default blink
          color =
              _blinkCtrl.value < 0.5 ? widget.sp2Color : widget.defaultColor;
        } else {
          // SP1–SP2 arasında ise hep default renginde
          color = widget.defaultColor;
        }

        return Text(
          widget.mainValue.toStringAsFixed(1),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        );
      },
    );
  }
}
