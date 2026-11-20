import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'vault_store.dart';

class AuthenticatorScreen extends StatefulWidget {
  const AuthenticatorScreen({super.key, required this.isArabic});
  final bool isArabic;

  @override
  State<AuthenticatorScreen> createState() => _AuthenticatorScreenState();
}

class _AuthenticatorScreenState extends State<AuthenticatorScreen> {
  List<TotpEntry> entries = [];
  final Map<String, String> codes = {};
  int secondsRemaining = 30;
  bool loading = true;
  Timer? timer;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshCodes());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await VaultStore.instance.loadTotpEntries();
      if (!mounted) return;
      setState(() {
        entries = result;
        loading = false;
      });
      await _refreshCodes();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refreshCodes() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = 30 - (now % 30);
    final next = <String, String>{};
    for (final entry in entries) {
      try {
        next[entry.id] = await _generateTotp(entry.secret, now);
      } catch (_) {
        next[entry.id] = '------';
      }
    }
    if (mounted) {
      setState(() {
        codes
          ..clear()
          ..addAll(next);
        secondsRemaining = remaining;
      });
    }
  }

  Future<String> _generateTotp(String encodedSecret, int unixSeconds) async {
    final keyBytes = _decodeBase32(encodedSecret);
    if (keyBytes.isEmpty) throw const FormatException('Empty secret');
    final counter = unixSeconds ~/ 30;
    final message = Uint8List(8);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      message[i] = value & 0xff;
      value >>= 8;
    }
    final mac = await Hmac.sha1().calculateMac(
      message,
      secretKey: SecretKey(keyBytes),
    );
    final bytes = mac.bytes;
    final offset = bytes.last & 0x0f;
    final binary = ((bytes[offset] & 0x7f) << 24) |
        ((bytes[offset + 1] & 0xff) << 16) |
        ((bytes[offset + 2] & 0xff) << 8) |
        (bytes[offset + 3] & 0xff);
    return (binary % 1000000).toString().padLeft(6, '0');
  }

  Uint8List _decodeBase32(String input) {
    final normalized = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      final index = alphabet.indexOf(char);
      if (index < 0) throw const FormatException('Invalid Base32 secret');
      buffer = (buffer << 5) | index;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xff);
      }
    }
    return Uint8List.fromList(output);
  }

  Future<void> _chooseAddMethod() async {
    final scan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Add 2FA account', 'إضافة حساب 2FA')),
        content: Text(t('Choose how to add the account.', 'اختر طريقة إضافة الحساب.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Enter manually', 'إدخال يدوي')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(t('Scan QR code', 'مسح QR')),
          ),
        ],
      ),
    );
    if (scan == null) return;
    if (!scan) {
      await _addEntry();
      return;
    }
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => QrScannerScreen(isArabic: widget.isArabic)),
    );
    if (payload == null || !mounted) return;
    try {
      final parsed = _parseOtpAuthUri(payload);
      await _addEntry(
        initialIssuer: parsed.issuer,
        initialAccount: parsed.account,
        initialSecret: parsed.secret,
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  TotpEntry _parseOtpAuthUri(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'otpauth' ||
        uri.host.toLowerCase() != 'totp') {
      throw FormatException(t('This is not a valid TOTP QR code.', 'رمز QR ليس رابط TOTP صالحاً.'));
    }
    final params = uri.queryParameters;
    final secretValue = params['secret']?.trim();
    if (secretValue == null || secretValue.isEmpty) {
      throw FormatException(t('The QR code has no secret key.', 'رمز QR لا يحتوي على مفتاح سري.'));
    }
    final algorithm = (params['algorithm'] ?? 'SHA1').toUpperCase();
    final digits = int.tryParse(params['digits'] ?? '6') ?? 0;
    final period = int.tryParse(params['period'] ?? '30') ?? 0;
    if (algorithm != 'SHA1' || digits != 6 || period != 30) {
      throw FormatException(t(
        'Only SHA1, 6-digit, 30-second TOTP accounts are supported.',
        'ندعم حالياً SHA1 ورموزاً من 6 أرقام تتجدد كل 30 ثانية فقط.',
      ));
    }
    final label = uri.pathSegments.isEmpty ? '' : uri.pathSegments.join('/');
    var labelIssuer = '';
    var account = label;
    final separator = label.indexOf(':');
    if (separator >= 0) {
      labelIssuer = label.substring(0, separator);
      account = label.substring(separator + 1);
    }
    final queryIssuer = (params['issuer'] ?? '').trim();
    final issuer = queryIssuer.isNotEmpty ? queryIssuer : labelIssuer.trim();
    if (issuer.isEmpty) {
      throw FormatException(t('The QR code has no service name.', 'رمز QR لا يحتوي على اسم الخدمة.'));
    }
    final normalizedSecret = secretValue.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (_decodeBase32(normalizedSecret).isEmpty) {
      throw FormatException(t('The QR secret key is invalid.', 'المفتاح السري في QR غير صالح.'));
    }
    return TotpEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      issuer: issuer,
      account: account.trim(),
      secret: normalizedSecret,
    );
  }

  Future<void> _addEntry({
    String initialIssuer = '',
    String initialAccount = '',
    String initialSecret = '',
  }) async {
    final issuer = TextEditingController(text: initialIssuer);
    final account = TextEditingController(text: initialAccount);
    final secret = TextEditingController(text: initialSecret);
    final formKey = GlobalKey<FormState>();
    final entry = await showDialog<TotpEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('Add authenticator', 'إضافة Authenticator')),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: issuer,
                decoration: InputDecoration(labelText: t('Service name', 'اسم الخدمة')),
                validator: (v) => v == null || v.trim().isEmpty
                    ? t('Required', 'مطلوب')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: account,
                decoration: InputDecoration(labelText: t('Account label (optional)', 'اسم الحساب (اختياري)')),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: secret,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: t('Base32 secret key', 'مفتاح Base32 السري'),
                  helperText: t('Use a test key only while testing.', 'استخدم مفتاحاً تجريبياً فقط أثناء الاختبار.'),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return t('Required', 'مطلوب');
                  try {
                    if (_decodeBase32(v.trim()).isEmpty) return t('Invalid key', 'المفتاح غير صالح');
                  } catch (_) {
                    return t('Enter a valid Base32 key.', 'أدخل مفتاح Base32 صالحاً.');
                  }
                  return null;
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                TotpEntry(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  issuer: issuer.text.trim(),
                  account: account.text.trim(),
                  secret: secret.text.trim().replaceAll(' ', '').toUpperCase(),
                ),
              );
            },
            child: Text(t('Save encrypted', 'حفظ مشفّراً')),
          ),
        ],
      ),
    );
    issuer.dispose();
    account.dispose();
    secret.dispose();
    if (entry == null) return;
    await VaultStore.instance.saveTotpEntry(entry);
    await _load();
  }

  Future<void> _delete(TotpEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Remove authenticator?', 'حذف حساب Authenticator؟')),
        content: Text(t('This removes the saved 2FA key from this vault.', 'سيحذف مفتاح 2FA المحفوظ من هذه الخزنة.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Remove', 'حذف'))),
        ],
      ),
    );
    if (yes == true) {
      await VaultStore.instance.deleteTotpEntry(entry.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Authenticator', 'الموثّق Authenticator'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chooseAddMethod,
        backgroundColor: const Color(0xFF254F43),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(t('Add 2FA', 'إضافة 2FA')),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phonelink_lock, size: 54, color: Color(0xFF254F43)),
                      const SizedBox(height: 14),
                      Text(t('No authenticator accounts yet', 'لا توجد حسابات Authenticator بعد'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(t('Add a test 2FA key to generate one-time codes.',
                          'أضف مفتاح 2FA تجريبياً لتوليد رموز تحقق مؤقتة.'),
                          textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.timer_outlined, color: Color(0xFF254F43)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t('Codes refresh every 30 seconds.',
                              'تتجدد الرموز كل 30 ثانية.'))),
                          Text('$secondsRemaining s',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...entries.map((entry) => Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(entry.issuer,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (entry.account.isNotEmpty) Text(entry.account),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: SelectableText(
                                    codes[entry.id] ?? '------',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      letterSpacing: 5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF254F43),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: t('Copy code', 'نسخ الرمز'),
                                  onPressed: codes[entry.id] == null
                                      ? null
                                      : () {
                                          Clipboard.setData(ClipboardData(text: codes[entry.id]!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(t('Code copied', 'تم نسخ الرمز'))),
                                          );
                                        },
                                  icon: const Icon(Icons.copy),
                                ),
                                IconButton(
                                  tooltip: t('Remove', 'حذف'),
                                  onPressed: () => _delete(entry),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ]),
                            ]),
                          ),
                        )),
                  ],
                ),
    );
  }
}


class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.isArabic});
  final bool isArabic;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool detected = false;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  void _onDetect(BarcodeCapture capture) {
    if (detected) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.trim().isEmpty) continue;
      detected = true;
      Navigator.of(context).pop(value.trim());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Scan authenticator QR', 'مسح رمز QR للموثّق')),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 190,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                t('Place the TOTP QR code inside the frame.',
                    'ضع رمز QR الخاص بـ TOTP داخل الإطار.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
