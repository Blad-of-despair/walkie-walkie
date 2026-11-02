import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isHost = true;
  final _nicknameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '3000');
  bool _connecting = false;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
  }

  Future<void> _loadLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (mounted) {
        setState(() => _localIp = ip);
        if (ip != null) {
          _ipController.text = ip;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _submit() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    final port = int.tryParse(_portController.text.trim()) ?? 3000;

    if (_isHost) {
      Navigator.pushReplacementNamed(context, '/main', arguments: {
        'mode': 'host',
        'nickname': nickname,
        'port': port,
      });
    } else {
      final ip = _ipController.text.trim();
      if (ip.isEmpty) return;
      Navigator.pushReplacementNamed(context, '/main', arguments: {
        'mode': 'join',
        'nickname': nickname,
        'host': ip,
        'port': port,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141628),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x1F3B82F6),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📡', style: TextStyle(fontSize: 56)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'WiFi Talkie',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF1F5F9),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Push-to-talk over your local network',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 32),

                // Mode toggle
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'Host',
                        icon: '📡',
                        selected: _isHost,
                        onTap: () => setState(() => _isHost = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeButton(
                        label: 'Join',
                        icon: '🔗',
                        selected: !_isHost,
                        onTap: () => setState(() => _isHost = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nickname
                TextField(
                  controller: _nicknameController,
                  maxLength: 20,
                  style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter your nickname',
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    counterStyle: const TextStyle(color: Color(0xFF475569)),
                    filled: true,
                    fillColor: const Color(0xFF141628),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                if (!_isHost) ...[
                  // Server IP
                  TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Server IP address',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      suffixIcon: _localIp != null
                          ? IconButton(
                              icon: const Icon(Icons.my_location, color: Color(0xFF475569)),
                              onPressed: () {
                                _ipController.text = _localIp!;
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF141628),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                ],

                // Port
                TextField(
                  controller: _portController,
                  style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Port',
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    filled: true,
                    fillColor: const Color(0xFF141628),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _connecting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _connecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isHost ? 'Start Channel' : 'Join Channel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D2042) : const Color(0xFF141628),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0x263B82F6)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
