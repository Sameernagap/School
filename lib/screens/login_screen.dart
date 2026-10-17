import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Sign-in screen with the three approved designs: Pre-primary (animal adventure), Primary
/// (rainbow & school) and Secondary (modern campus).
///
/// Each design is the approved artwork (assets/login/bg_*.webp) with the live parts laid on top
/// at the exact positions of the mockup: school logo, school name, tagline, role choice, the form
/// and the Login button. The whole design is scaled to the phone, so it looks the same on every
/// screen size. School name, tagline and logo come from Odoo (Settings › School › Mobile App).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Positions of the live parts, in points of the 390 pt wide design.
class _Geom {
  const _Geom({
    required this.height,
    required this.logo,
    required this.name,
    required this.tagline,
    required this.tiles,
    required this.left,
    required this.right,
    required this.fieldHeight,
    required this.loginY,
    required this.passwordY,
    required this.rememberY,
    required this.button,
  });

  final double height;
  final Rect logo;
  final Rect name;
  final Rect tagline;
  final Map<String, Rect> tiles;
  final double left;
  final double right;
  final double fieldHeight;
  final double loginY;
  final double passwordY;
  final double rememberY;
  final Rect button;
}

const double _designWidth = 390;

const Map<String, _Geom> _geoms = {
  'preprimary': _Geom(
    height: 868.0,
    logo: Rect.fromLTRB(164.6, 73.8, 222.5, 121.5),
    name: Rect.fromLTRB(73.5, 121.5, 310.7, 157.7),
    tagline: Rect.fromLTRB(86.8, 158.5, 303.8, 177.1),
    tiles: {
      'parent': Rect.fromLTRB(40.8, 425.3, 139.5, 527.7),
      'student': Rect.fromLTRB(148.4, 425.3, 247.4, 527.4),
      'teacher': Rect.fromLTRB(256.3, 425.3, 354.7, 527.1),
    },
    left: 40.8,
    right: 354.7,
    fieldHeight: 46.3,
    loginY: 562.9,
    passwordY: 617.4,
    rememberY: 663.7,
    button: Rect.fromLTRB(43.4, 687.4, 352.4, 742.7),
  ),
  'primary': _Geom(
    height: 886.4,
    logo: Rect.fromLTRB(165.8, 38.4, 229.6, 100.5),
    name: Rect.fromLTRB(50.2, 101.9, 345.7, 143.3),
    tagline: Rect.fromLTRB(88.6, 138.3, 307.3, 156.0),
    tiles: {
      'parent': Rect.fromLTRB(36.0, 446.4, 137.1, 538.9),
      'student': Rect.fromLTRB(147.1, 446.4, 248.8, 538.6),
      'teacher': Rect.fromLTRB(258.8, 446.1, 359.9, 538.3),
    },
    left: 36.0,
    right: 359.9,
    fieldHeight: 47.3,
    loginY: 575.1,
    passwordY: 630.5,
    rememberY: 677.8,
    button: Rect.fromLTRB(37.8, 702.0, 358.1, 758.4),
  ),
  'secondary': _Geom(
    height: 908.4,
    logo: Rect.fromLTRB(155.0, 33.3, 239.8, 106.0),
    name: Rect.fromLTRB(45.4, 109.0, 339.1, 145.9),
    tagline: Rect.fromLTRB(72.7, 151.4, 305.8, 169.0),
    tiles: {
      'parent': Rect.fromLTRB(33.3, 457.2, 136.0, 552.3),
      'student': Rect.fromLTRB(145.6, 457.5, 248.3, 552.0),
      'teacher': Rect.fromLTRB(257.7, 457.5, 359.4, 551.7),
    },
    left: 33.3,
    right: 359.4,
    fieldHeight: 48.4,
    loginY: 589.4,
    passwordY: 646.3,
    rememberY: 694.6,
    button: Rect.fromLTRB(34.2, 719.4, 358.5, 777.3),
  ),
};

const _defaultTaglines = {
  'preprimary': 'Learn · Play · Be Happy',
  'primary': 'Learn · Grow · Achieve',
  'secondary': 'Learn Today · Lead Tomorrow',
};
const _defaultLogoPresets = {'preprimary': 'sun_book', 'primary': 'sun_book', 'secondary': 'cap'};
const _logoPresets = {'sun_book', 'shield', 'people', 'cap'};

const _roleColors = {
  'parent': Color(0xFFF0287A),
  'student': Color(0xFF1D7FF0),
  'teacher': Color(0xFF1E9B48),
};
const _roleLabels = {'parent': 'Parent', 'student': 'Student', 'teacher': 'Teacher'};

const _buttonColors = {
  'preprimary': [Color(0xFFFF3175), Color(0xFFFF1A6B)],
  'primary': [Color(0xFF0080FF), Color(0xFF0066FF)],
  'secondary': [Color(0xFFFF7600), Color(0xFFFF6400)],
};

const _ink = Color(0xFF111827);
const _iconInk = Color(0xFF1F2433);
const _hint = Color(0xFF4A5168);
const _link = Color(0xFF0A58F0);
const _navy = Color(0xFF1B2A6B);

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _hidePassword = true;
  bool _remember = true;
  String _role = 'parent';
  Map<String, dynamic>? _school;
  bool _schoolTried = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _server.text = state.serverUrl;
    _remember = state.rememberMe;
    _login.text = state.savedLogin;
    _role = state.mode == 'teacher' ? 'teacher' : 'parent';
    _loadSchool();
    final message = state.sessionMessage;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showMessage(context, message, error: true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final level in _geoms.keys) {
      precacheImage(AssetImage('assets/login/bg_${_short(level)}.webp'), context);
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _server.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  static String _short(String level) =>
      const {'preprimary': 'pre', 'primary': 'pri', 'secondary': 'sec'}[level]!;

  /// Name, logo, tagline and design of each section, from the school server.
  Future<void> _loadSchool() async {
    if (mounted) setState(() => _schoolTried = false);
    try {
      final data = await context.read<AppState>().api.get('/ping');
      if (data is Map && data['school'] is Map && mounted) {
        setState(() => _school = Map<String, dynamic>.from(data['school'] as Map));
      }
    } catch (_) {
      // server not reachable yet: built-in design, logo and a generic name
    }
    if (mounted) setState(() => _schoolTried = true);
  }

  /// True when the school set one sign-in design for every phone in Odoo.
  bool get _fixed => _school?['login_style_fixed'] == true;

  /// Sections the school has, in school order.
  List<String> get _levels {
    final raw = _school?['login_levels'];
    final levels = raw is List ? raw.map((e) => e.toString()).where(_geoms.containsKey).toList() : <String>[];
    return levels.isEmpty ? const ['preprimary', 'primary', 'secondary'] : levels;
  }

  /// Design to show: the one set in Odoo, else the one chosen / remembered on this phone, else the
  /// school's only section. Null: ask the user to choose their section first.
  String? get _level {
    if (_fixed) {
      final style = (_school?['login_style'] ?? '').toString();
      if (_geoms.containsKey(style)) return style;
    }
    final saved = context.read<AppState>().loginLevel;
    if (saved != null && _geoms.containsKey(saved)) return saved;
    if (_school != null && _levels.length == 1) return _levels.first;
    return null;
  }

  /// Still waiting for the school's answer (only matters before a section is known).
  bool get _waiting => _school == null && !_schoolTried;

  Map<String, dynamic> _section(String level) {
    final sections = _school?['sections'];
    if (sections is Map && sections[level] is Map) return Map<String, dynamic>.from(sections[level] as Map);
    return {
      'name': (_school?['name'] ?? 'Our School').toString(),
      'tagline': _defaultTaglines[level],
      'logo_url': null,
      'logo_preset': _defaultLogoPresets[level],
    };
  }

  Future<void> _submit() async {
    final login = _login.text.trim();
    if (login.isEmpty) {
      showMessage(context, 'Enter your username or mobile number', error: true);
      return;
    }
    if (_password.text.isEmpty) {
      showMessage(context, 'Enter your password', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await state.setServer(_server.text);
      await state.login(login, _password.text, role: _role, remember: _remember);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final controller = TextEditingController(text: _login.text);
    final login = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username / mobile number / email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Send link')),
        ],
      ),
    );
    if (login == null || login.trim().isEmpty || !mounted) return;
    final state = context.read<AppState>();
    await state.setServer(_server.text);
    if (!mounted) return;
    await runAction(context, () async {
      final data = await state.api.post('/auth/password/reset', {'login': login.trim()});
      if (mounted) showMessage(context, (data as Map)['message'].toString());
    });
  }

  /// Gear button: choose the section's sign-in design, or set the school server.
  Future<void> _settingsSheet() async {
    final state = context.read<AppState>();
    final current = _level;
    final canChoose = !_fixed && _levels.length > 1;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canChoose) ...[
                Text('My section',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _ink)),
                Text('Choose the sign-in screen for your school section.',
                    style: GoogleFonts.poppins(fontSize: 13, color: _hint)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final level in _levels) ...[
                      if (level != _levels.first) const SizedBox(width: 10),
                      Expanded(child: _SectionChoice(level: level, selected: level == current)),
                    ],
                  ],
                ),
                const Divider(height: 28),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _svg('settings', 22, _iconInk),
                title: const Text('School server'),
                subtitle: Text(state.serverUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, 'server'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'server') {
      await _serverDialog();
    } else {
      await state.setLoginLevel(choice);
      if (mounted) setState(() {});
    }
  }

  /// Address of the school's Odoo server (first-time setup).
  Future<void> _serverDialog() async {
    final state = context.read<AppState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('School server'),
        content: TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://school.example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _server.text), child: const Text('Connect')),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await state.setServer(value);
    _server.text = state.serverUrl;
    if (!mounted) return;
    await runAction(context, () async {
      await state.api.get('/ping');
    }, success: 'Connected to ${state.serverUrl}');
    _loadSchool();
  }

  /// First opening (no design set in Odoo): the user picks their section once; the phone remembers it.
  Widget _chooser() {
    final name = (_school?['name'] ?? '').toString();
    final reached = _school != null;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            children: [
              Center(
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _SchoolLogo(level: 'primary', section: _section(_levels.contains('primary') ? 'primary' : _levels.first)),
                ),
              ),
              const SizedBox(height: 12),
              if (name.isNotEmpty)
                Text(name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(fontSize: 24, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 18),
              Text('Choose your section',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w600, color: _ink)),
              Text('Pick the section of your class or your child\'s class. You can change it later with the ⚙ button.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13.5, color: _hint)),
              const SizedBox(height: 20),
              for (final level in _levels) ...[
                _SectionCard(
                  level: level,
                  onTap: () async {
                    await context.read<AppState>().setLoginLevel(level);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (!reached) ...[
                const SizedBox(height: 4),
                Text('The school server could not be reached. Check the address below.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFFB4232F))),
              ],
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: _serverDialog,
                  icon: _svg('settings', 18, _iconInk),
                  label: Text('School server: ${context.watch<AppState>().serverUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12.5, color: _iconInk)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7FC),
          body: _waiting ? const Center(child: CircularProgressIndicator()) : _chooser(),
        ),
      );
    }
    final geom = _geoms[level]!;
    final background = 'assets/login/bg_${_short(level)}.webp';
    // full screen size (does not shrink when the keyboard opens, so the design keeps its scale)
    final screen = MediaQuery.sizeOf(context);
    final scale = math.min(screen.width / _designWidth, screen.height / geom.height);
    final width = _designWidth * scale;
    final height = geom.height * scale;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: level == 'secondary' ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // soft copy of the artwork behind the side (or top/bottom) bands of odd-sized screens
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Image.asset(background, fit: BoxFit.cover, cacheWidth: 200),
              ),
            ),
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screen.height),
                child: Center(
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: FittedBox(
                      child: SizedBox(
                        width: _designWidth,
                        height: geom.height,
                        child: _design(level, geom, background, (width * dpr).round()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _design(String level, _Geom g, String background, int cacheWidth) {
    final section = _section(level);
    final name = (section['name'] ?? '').toString().trim();
    final tagline = (section['tagline'] ?? '').toString();
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(background, fit: BoxFit.fill, cacheWidth: cacheWidth, filterQuality: FilterQuality.medium),
        ),
        // school server address (first-time setup)
        Positioned(
          left: 12,
          top: 48,
          child: Tooltip(
            message: 'Sign-in settings',
            child: Material(
              color: Colors.white.withAlpha(185),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _settingsSheet,
                child: Padding(padding: const EdgeInsets.all(6), child: _svg('settings', 18, _iconInk)),
              ),
            ),
          ),
        ),
        // logo
        Positioned.fromRect(rect: g.logo, child: _SchoolLogo(level: level, section: section)),
        // school name
        Positioned.fromRect(rect: g.name.inflate(2), child: _SchoolName(level: level, name: name)),
        // tagline
        Positioned.fromRect(
          rect: Rect.fromLTRB(g.tagline.left - 30, g.tagline.top, g.tagline.right + 30, g.tagline.bottom),
          child: FittedBox(fit: BoxFit.scaleDown, child: _Tagline(level: level, text: tagline)),
        ),
        // role choice: the cards are part of the artwork, the app adds the touch and the selection ring
        for (final entry in g.tiles.entries)
          Positioned.fromRect(
            rect: entry.value.inflate(2),
            child: _RoleTile(
              role: entry.key,
              selected: _role == entry.key,
              onTap: () => setState(() => _role = entry.key),
            ),
          ),
        // username / mobile number
        Positioned(
          left: g.left,
          width: g.right - g.left,
          top: g.loginY - g.fieldHeight / 2,
          height: g.fieldHeight,
          child: _Field(
            controller: _login,
            hint: 'Username / Mobile Number',
            icon: 'user',
            keyboardType: TextInputType.emailAddress,
            autofill: AutofillHints.username,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
        ),
        // password
        Positioned(
          left: g.left,
          width: g.right - g.left,
          top: g.passwordY - g.fieldHeight / 2,
          height: g.fieldHeight,
          child: _Field(
            controller: _password,
            focusNode: _passwordFocus,
            hint: 'Password',
            icon: 'lock',
            obscure: _hidePassword,
            autofill: AutofillHints.password,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
              visualDensity: VisualDensity.compact,
              tooltip: _hidePassword ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: _svg(_hidePassword ? 'eye' : 'eye-off', 22, _iconInk),
            ),
          ),
        ),
        // remember me / forgot password
        Positioned(
          left: g.left - 4,
          right: _designWidth - g.right - 6,
          top: g.rememberY - 18,
          height: 36,
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _remember = !_remember),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      _CheckBox(value: _remember, color: _buttonColors[level]!.last),
                      const SizedBox(width: 10),
                      Text('Remember me', style: GoogleFonts.poppins(fontSize: 14, color: _ink)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
                onPressed: _forgot,
                child: Text('Forgot Password?',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _link)),
              ),
            ],
          ),
        ),
        // login
        Positioned.fromRect(
          rect: g.button,
          child: _LoginButton(colors: _buttonColors[level]!, busy: _busy, onPressed: _submit),
        ),
      ],
    );
  }
}

Widget _svg(String name, double size, Color color) => SvgPicture.asset(
      'assets/login/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

/// Logo of the section: the one uploaded in Odoo, else the chosen design logo (shipped with the app
/// too, so it shows before the server answers), else the school icon.
class _SchoolLogo extends StatelessWidget {
  const _SchoolLogo({required this.level, required this.section});

  final String level;
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final preset = section['logo_preset']?.toString();
    final url = section['logo_url']?.toString();
    final bundled = (preset != null && _logoPresets.contains(preset)) ? 'assets/login/logo_$preset.png' : null;
    Widget fallback() => bundled != null
        ? Image.asset(bundled, fit: BoxFit.contain)
        : Padding(padding: const EdgeInsets.all(6), child: _svg('school', 40, _navy));
    Widget image;
    if (bundled != null) {
      image = fallback(); // same picture as the server would send
    } else if (url != null) {
      final api = context.read<AppState>().api;
      image = Image.network(api.url(url), fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback());
    } else {
      image = fallback();
    }
    if (level == 'secondary') return image;
    // pre-primary and primary: round white badge with an orange ring
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF5A524), width: level == 'primary' ? 2.4 : 2),
            boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: ClipOval(child: image),
        ),
      ),
    );
  }
}

/// Colours of the letters of the school name, per word, like the mockups.
List<(String, Color)> _nameLetters(String level, String name) {
  const palettes = {
    'preprimary': [
      [Color(0xFFE8232E), Color(0xFFF57C00)],
      [Color(0xFF1E9E3A), Color(0xFF1E9E3A)],
      [Color(0xFF8E24AA), Color(0xFF9C27B0)],
    ],
    'primary': [
      [Color(0xFFE53935), Color(0xFFFB8C00)],
      [Color(0xFF2E9E3A), Color(0xFF1E88E5)],
      [Color(0xFF1E5BD8), Color(0xFF7B1FA2)],
    ],
  };
  const navy = Color(0xFF18306E);
  const orange = Color(0xFFF4511E);
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final letters = <(String, Color)>[];
  for (var w = 0; w < words.length; w++) {
    final word = words[w];
    Color colorAt(int i) {
      if (level == 'secondary') {
        // middle word(s) orange: "Sunrise Public School", or the 2nd of two words
        final orangeWord = words.length >= 2 && w > 0 && (w < words.length - 1 || words.length == 2);
        return orangeWord ? orange : navy;
      }
      final pair = palettes[level]![w % 3];
      final t = word.length > 1 ? i / (word.length - 1) : 0.0;
      return Color.lerp(pair[0], pair[1], t)!;
    }

    final chars = word.characters.toList();
    for (var i = 0; i < chars.length; i++) {
      letters.add((chars[i], colorAt(i)));
    }
    if (w < words.length - 1) letters.add((' ', navy));
  }
  return letters;
}

class _SchoolName extends StatelessWidget {
  const _SchoolName({required this.level, required this.name});

  final String level;
  final String name;

  @override
  Widget build(BuildContext context) {
    final display = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
    final shown = display.isEmpty ? 'Our School' : display;
    final letters = _nameLetters(level, shown);
    if (level == 'primary') {
      return CustomPaint(
        painter: _ArcNamePainter(
          letters: letters,
          style: GoogleFonts.baloo2(fontSize: 38, fontWeight: FontWeight.w800, height: 1),
          sag: 9,
        ),
      );
    }
    final pre = level == 'preprimary';
    final base = pre
        ? GoogleFonts.fredoka(fontSize: 30, fontWeight: FontWeight.w700, height: 1)
        : GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.w700, height: 1);
    final spans = [for (final (ch, color) in letters) TextSpan(text: ch, style: TextStyle(color: color))];
    final fill = Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      style: pre
          ? base.copyWith(shadows: const [Shadow(color: Color(0x40502800), offset: Offset(0, 2), blurRadius: 2)])
          : base,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: pre
          ? Stack(
              children: [
                Text(
                  shown,
                  maxLines: 1,
                  style: base.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 5
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.white,
                  ),
                ),
                fill,
              ],
            )
          : fill,
    );
  }
}

/// Primary: school name on a gentle arch, letters outlined in white (fits any length).
class _ArcNamePainter extends CustomPainter {
  _ArcNamePainter({required this.letters, required this.style, required this.sag});

  final List<(String, Color)> letters;
  final TextStyle style;
  final double sag;

  List<TextPainter> _layout(double fontSize, {bool stroke = false}) => [
        for (final (ch, color) in letters)
          TextPainter(
            text: TextSpan(
              text: ch,
              style: stroke
                  ? style.copyWith(
                      fontSize: fontSize,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = fontSize * 0.2
                        ..strokeJoin = StrokeJoin.round
                        ..color = Colors.white)
                  : style.copyWith(
                      fontSize: fontSize,
                      color: color,
                      shadows: const [Shadow(color: Color(0x40002878), offset: Offset(0, 3), blurRadius: 4)]),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    if (letters.isEmpty) return;
    var fontSize = math.min(style.fontSize ?? 38, size.height * 0.95);
    var fills = _layout(fontSize);
    var total = fills.fold<double>(0, (sum, p) => sum + p.width);
    final maxWidth = size.width * 0.98;
    if (total > maxWidth) {
      fontSize *= maxWidth / total;
      fills = _layout(fontSize);
      total = fills.fold<double>(0, (sum, p) => sum + p.width);
    }
    final strokes = _layout(fontSize, stroke: true);
    final arch = math.min(sag, size.height * 0.25) * (total / maxWidth).clamp(0.4, 1.0);
    final radius = (total * total / 4 + arch * arch) / (2 * arch);
    final centre = Offset(size.width / 2, size.height / 2 - arch / 2 + radius);
    for (final layer in [strokes, fills]) {
      var along = -total / 2;
      for (var i = 0; i < layer.length; i++) {
        final p = layer[i];
        final angle = (along + p.width / 2) / radius;
        canvas.save();
        canvas.translate(centre.dx + radius * math.sin(angle), centre.dy - radius * math.cos(angle));
        canvas.rotate(angle);
        p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
        canvas.restore();
        along += fills[i].width;
      }
    }
  }

  @override
  bool shouldRepaint(_ArcNamePainter old) => old.letters != letters || old.style != style;
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.level, required this.text});

  final String level;
  final String text;

  @override
  Widget build(BuildContext context) {
    switch (level) {
      case 'preprimary':
        return Text(text,
            maxLines: 1,
            style: GoogleFonts.fredoka(fontSize: 17.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E1A2E)));
      case 'primary':
        final style = GoogleFonts.baloo2(fontSize: 19.5, fontWeight: FontWeight.w700, height: 1);
        return Stack(
          children: [
            Text(text,
                maxLines: 1,
                style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 4
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.white)),
            Text(text, maxLines: 1, style: style.copyWith(color: _navy)),
          ],
        );
      default:
        return Text(text,
            maxLines: 1, style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w500, color: _navy));
    }
  }
}

/// Touch area over a role card of the artwork, with a coloured ring and tick when chosen.
class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.selected, required this.onTap});

  final String role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[role]!;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sign in as ${_roleLabels[role]}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? color : Colors.transparent, width: 3),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withAlpha(80), blurRadius: 14, offset: const Offset(0, 6))]
                      : null,
                ),
              ),
            ),
            if (selected)
              Positioned(
                right: -6,
                top: -8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Text field that always fills the height of its slot in the design (grey box, icon, text, optional
/// button), with a blue border while typing.
class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.obscure = false,
    this.keyboardType,
    this.autofill,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final String icon;
  final FocusNode? focusNode;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? autofill;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_Field old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6FA),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: focused ? const Color(0xFF8AA9F5) : const Color(0xFFE9ECF2),
            width: focused ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            _svg(widget.icon, 22, _iconInk),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                autofillHints: widget.autofill == null ? null : [widget.autofill!],
                maxLines: 1,
                style: GoogleFonts.poppins(fontSize: 14.5, color: _ink),
                cursorColor: const Color(0xFF3B6FE0),
                // The app theme gives every TextField its own white rounded box and focus border.
                // Here the outer container is the box, so all of the theme's borders and fill are
                // switched off (border: none alone does not override enabled/focused borders).
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.poppins(fontSize: 14.5, color: _hint),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (widget.suffix != null) widget.suffix! else const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.value, required this.color});

  final bool value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: value ? color : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: value ? color : const Color(0xFF50566A), width: 1.6),
      ),
      child: value ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.colors, required this.busy, required this.onPressed});

  final List<Color> colors;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final radius = BorderRadius.circular(box.maxHeight / 2);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
          boxShadow: [BoxShadow(color: colors.last.withAlpha(90), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: busy ? null : onPressed,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Login',
                            style: GoogleFonts.fredoka(
                                fontSize: box.maxHeight * 0.44, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                      ],
                    ),
            ),
          ),
        ),
      );
    });
  }
}

/// Small picture of one section's sign-in design in the "My section" sheet.
class _SectionChoice extends StatelessWidget {
  const _SectionChoice({required this.level, required this.selected});

  final String level;
  final bool selected;

  static const _labels = {'preprimary': 'Pre-primary', 'primary': 'Primary', 'secondary': 'Secondary'};
  static const _colors = {
    'preprimary': Color(0xFFF0287A),
    'primary': Color(0xFF1D7FF0),
    'secondary': Color(0xFFFF6A00),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[level]!;
    final short = const {'preprimary': 'pre', 'primary': 'pri', 'secondary': 'sec'}[level];
    return Semantics(
      button: true,
      selected: selected,
      label: '${_labels[level]} sign-in screen',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, level),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? color : const Color(0xFFE3E6EE), width: selected ? 3 : 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 0.62,
                  child: Image.asset('assets/login/bg_$short.webp',
                      fit: BoxFit.cover, alignment: Alignment.topCenter, cacheWidth: 240),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(_labels[level]!,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? color : _ink)),
          ],
        ),
      ),
    );
  }
}

/// Big card on the "Choose your section" screen.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.level, required this.onTap});

  final String level;
  final VoidCallback onTap;

  static const _labels = {'preprimary': 'Pre-primary', 'primary': 'Primary', 'secondary': 'Secondary'};
  static const _classes = {'preprimary': 'Playgroup · Nursery · LKG · UKG', 'primary': 'Class 1 – 5', 'secondary': 'Class 6 and above'};
  static const _colors = {
    'preprimary': Color(0xFFF0287A),
    'primary': Color(0xFF1D7FF0),
    'secondary': Color(0xFFFF6A00),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[level]!;
    final short = const {'preprimary': 'pre', 'primary': 'pri', 'secondary': 'sec'}[level];
    return Semantics(
      button: true,
      label: '${_labels[level]}, ${_classes[level]}',
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: color.withAlpha(70), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Image.asset('assets/login/bg_$short.webp',
                    fit: BoxFit.cover, alignment: const Alignment(0, -0.35), cacheWidth: 320),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_labels[level]!,
                        style: GoogleFonts.fredoka(fontSize: 21, fontWeight: FontWeight.w600, color: color)),
                    Text(_classes[level]!, style: GoogleFonts.poppins(fontSize: 13, color: _hint)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.arrow_forward_rounded, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
