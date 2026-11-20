import 'package:flutter/material.dart';
import 'vault_store.dart';
import 'authenticator_screen.dart';

void main() => runApp(const MyVaultApp());

const cream = Color(0xFFF5F0E5);
const charcoal = Color(0xFF222420);
const forest = Color(0xFF254F43);
const terracotta = Color(0xFFCF6248);

class MyVaultApp extends StatefulWidget {
  const MyVaultApp({super.key});
  @override
  State<MyVaultApp> createState() => _MyVaultAppState();
}

class _MyVaultAppState extends State<MyVaultApp> {
  bool isArabic = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'My Vault',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest, secondary: terracotta, surface: cream),
      appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: charcoal, elevation: 0),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    ),
    home: Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: VaultGate(isArabic: isArabic, onToggleLanguage: () => setState(() => isArabic = !isArabic)),
    ),
  );
}

class VaultGate extends StatefulWidget {
  const VaultGate({super.key, required this.isArabic, required this.onToggleLanguage});
  final bool isArabic;
  final VoidCallback onToggleLanguage;
  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  bool? hasMaster;
  bool unlocked = false;
  bool busy = false;
  String? error;
  final password = TextEditingController();
  final confirm = TextEditingController();
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await VaultStore.instance.initialize();
      final exists = await VaultStore.instance.hasMasterPassword();
      if (mounted) setState(() => hasMaster = exists);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      if (hasMaster == false) {
        if (password.text != confirm.text) {
          throw ArgumentError(t('The passwords do not match.', 'كلمتا المرور غير متطابقتين.'));
        }
        await VaultStore.instance.createMasterPassword(password.text);
      } else {
        final ok = await VaultStore.instance.unlock(password.text);
        if (!ok) throw ArgumentError(t('Incorrect master password.', 'كلمة المرور الرئيسية غير صحيحة.'));
      }
      if (mounted) setState(() { hasMaster = true; unlocked = true; });
    } catch (e) {
      if (mounted) setState(() => error = e is ArgumentError
          ? e.message.toString()
          : t('Could not open the vault. Please try again.', 'تعذر فتح الخزنة. حاول مرة أخرى.'));
    } finally {
      // Do not keep the master password in UI controllers after an attempt.
      password.clear();
      confirm.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked) {
      return VaultHome(
        isArabic: widget.isArabic,
        onToggleLanguage: widget.onToggleLanguage,
        onLock: () async {
          await VaultStore.instance.lock();
          if (mounted) setState(() => unlocked = false);
          password.clear();
          confirm.clear();
        },
      );
    }
    final loading = hasMaster == null && error == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vault', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(onPressed: widget.onToggleLanguage, icon: const Icon(Icons.language), label: Text(t('العربية', 'English'))),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shield_moon_outlined, color: forest, size: 58),
                    const SizedBox(height: 18),
                    Text(t('Your private vault', 'خزنتك الخاصة'), textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: charcoal)),
                    const SizedBox(height: 8),
                    Text(
                      loading ? t('Preparing secure storage…', 'جارٍ تجهيز التخزين الآمن…')
                        : (hasMaster == true ? t('Enter your master password to unlock.', 'أدخل كلمة المرور الرئيسية لفتح الخزنة.')
                        : t('Create a master password to protect your vault.', 'أنشئ كلمة مرور رئيسية لحماية خزنتك.')),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 22),
                    if (!loading) ...[
                      TextField(controller: password, obscureText: true, autocorrect: false, enableSuggestions: false,
                        decoration: InputDecoration(labelText: t('Master password', 'كلمة المرور الرئيسية'), prefixIcon: const Icon(Icons.lock_outline))),
                      if (hasMaster == false) ...[
                        const SizedBox(height: 12),
                        TextField(controller: confirm, obscureText: true, autocorrect: false, enableSuggestions: false,
                          decoration: InputDecoration(labelText: t('Confirm master password', 'تأكيد كلمة المرور'), prefixIcon: const Icon(Icons.lock_reset))),
                        const SizedBox(height: 8),
                        Text(t('Use at least 12 characters. If you forget it, your encrypted vault cannot be recovered.',
                          'استخدم 12 حرفاً على الأقل. إذا نسيتها فلن يمكن استعادة بيانات الخزنة المشفرة.'),
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(hasMaster == true ? t('Unlock vault', 'فتح الخزنة') : t('Create vault', 'إنشاء الخزنة')),
                        ),
                      ),
                    ] else const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VaultHome extends StatefulWidget {
  const VaultHome({super.key, required this.isArabic, required this.onToggleLanguage, required this.onLock});
  final bool isArabic;
  final VoidCallback onToggleLanguage;
  final VoidCallback onLock;
  @override
  State<VaultHome> createState() => _VaultHomeState();
}

class _VaultHomeState extends State<VaultHome> {
  List<VaultEntry> entries = [];
  bool loading = true;
  String query = '';
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await VaultStore.instance.loadEntries();
      if (mounted) setState(() { entries = result; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([VaultEntry? existing]) async {
    final entry = await showDialog<VaultEntry>(
      context: context, builder: (_) => EntryEditor(isArabic: widget.isArabic, entry: existing),
    );
    if (entry == null) return;
    await VaultStore.instance.saveEntry(entry);
    await _load();
  }

  Future<void> _delete(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Delete account?', 'حذف الحساب؟')),
        content: Text(t('This saved item will be removed from this device.', 'سيتم حذف هذا الحساب المحفوظ من هذا الجهاز.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Delete', 'حذف'))),
        ],
      ),
    );
    if (confirmed == true) {
      await VaultStore.instance.deleteEntry(entry.id);
      await _load();
    }
  }

  void _showEntry(VaultEntry e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.service),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _DetailLine(label: t('Username', 'اسم المستخدم'), value: e.username),
            _DetailLine(label: t('Email', 'البريد الإلكتروني'), value: e.email),
            _DetailLine(label: t('Phone', 'الهاتف'), value: e.phone),
            _DetailLine(label: t('Password', 'كلمة المرور'), value: e.password.isEmpty ? '' : '••••••••••'),
            _DetailLine(label: t('Website', 'الموقع'), value: e.website),
            _DetailLine(label: t('Category', 'التصنيف'), value: e.category),
            _DetailLine(label: t('Notes', 'ملاحظات'), value: e.notes),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Close', 'إغلاق')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = entries.where((e) {
      final q = query.toLowerCase();
      return e.service.toLowerCase().contains(q) || e.username.toLowerCase().contains(q) ||
        e.email.toLowerCase().contains(q) || e.category.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vault', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: t('Language', 'اللغة'), onPressed: widget.onToggleLanguage, icon: const Icon(Icons.language)),
          IconButton(
            tooltip: t('Authenticator', 'الموثّق'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AuthenticatorScreen(isArabic: widget.isArabic),
              ),
            ),
            icon: const Icon(Icons.phonelink_lock),
          ),
          IconButton(tooltip: t('Lock vault', 'قفل الخزنة'), onPressed: widget.onLock, icon: const Icon(Icons.lock_outline)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(), backgroundColor: forest, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: Text(t('Add account', 'إضافة حساب')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(t('Your digital life, safely stored.', 'حياتك الرقمية، محفوظة بأمان.'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: charcoal)),
          const SizedBox(height: 6),
          Text(t('${entries.length} saved accounts', '${entries.length} حساب محفوظ'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          TextField(onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(hintText: t('Search accounts…', 'ابحث في الحسابات…'), prefixIcon: const Icon(Icons.search))),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Card(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Icon(Icons.lock_person_outlined, size: 48, color: forest),
                const SizedBox(height: 12),
                Text(entries.isEmpty ? t('Your vault is empty', 'خزنتك فارغة') : t('No matching accounts', 'لا توجد حسابات مطابقة'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text(entries.isEmpty
                  ? t('Add your first account. Its details will be encrypted before being saved.', 'أضف أول حساب. سيتم تشفير بياناته قبل حفظها.')
                  : t('Try another search term.', 'جرّب كلمة بحث أخرى.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              ]),
            ))
          else
            ...filtered.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _showEntry(e),
                leading: CircleAvatar(backgroundColor: cream,
                  child: Text(e.service.isEmpty ? '?' : e.service.characters.first.toUpperCase(),
                    style: const TextStyle(color: forest, fontWeight: FontWeight.bold))),
                title: Text(e.service, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(e.email.isNotEmpty ? e.email : (e.username.isNotEmpty ? e.username : e.category)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) { if (v == 'edit') _edit(e); if (v == 'delete') _delete(e); },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(t('Edit', 'تعديل'))),
                    PopupMenuItem(value: 'delete', child: Text(t('Delete', 'حذف'))),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 14),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.verified_user_outlined, color: forest),
              const SizedBox(width: 10),
              Expanded(child: Text(t(
                'Local encryption is enabled. Your master password is not stored. If you forget it, this local vault cannot be unlocked.',
                'التشفير المحلي مفعّل. لا يتم حفظ كلمة المرور الرئيسية. إذا نسيتها فلن تتمكن من فتح هذه الخزنة.',
              ), style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ]),
          )),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 2),
        SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, required this.isArabic, this.entry});
  final bool isArabic;
  final VaultEntry? entry;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final TextEditingController service, username, email, phone, password, website, notes;
  late String category;
  bool showPassword = false;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    service = TextEditingController(text: e?.service ?? '');
    username = TextEditingController(text: e?.username ?? '');
    email = TextEditingController(text: e?.email ?? '');
    phone = TextEditingController(text: e?.phone ?? '');
    password = TextEditingController(text: e?.password ?? '');
    website = TextEditingController(text: e?.website ?? '');
    notes = TextEditingController(text: e?.notes ?? '');
    category = e?.category ?? 'Other';
  }

  @override
  void dispose() {
    service.dispose(); username.dispose(); email.dispose(); phone.dispose();
    password.dispose(); website.dispose(); notes.dispose();
    super.dispose();
  }

  Widget field(String label, TextEditingController controller, {bool secret = false, int lines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller, obscureText: secret && !showPassword,
        maxLines: secret ? 1 : lines, keyboardType: keyboard,
        autocorrect: false, enableSuggestions: !secret,
        decoration: InputDecoration(labelText: label,
          suffixIcon: secret ? IconButton(
            onPressed: () => setState(() => showPassword = !showPassword),
            icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
          ) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const categories = ['Other', 'Email', 'Social', 'Work', 'Finance', 'Shopping', 'Gaming'];
    return AlertDialog(
      title: Text(widget.entry == null ? t('Add account', 'إضافة حساب') : t('Edit account', 'تعديل الحساب')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          field(t('Service / website *', 'اسم الخدمة أو الموقع *'), service),
          field(t('Username', 'اسم المستخدم'), username),
          field(t('Email address', 'البريد الإلكتروني'), email, keyboard: TextInputType.emailAddress),
          field(t('Phone number', 'رقم الهاتف'), phone, keyboard: TextInputType.phone),
          field(t('Password', 'كلمة المرور'), password, secret: true),
          field(t('Website URL', 'رابط الموقع'), website, keyboard: TextInputType.url),
          DropdownButtonFormField<String>(
            value: category, decoration: InputDecoration(labelText: t('Category', 'التصنيف')),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { if (v != null) setState(() => category = v); },
          ),
          const SizedBox(height: 12),
          field(t('Notes', 'ملاحظات'), notes, lines: 3),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('Cancel', 'إلغاء'))),
        FilledButton(
          onPressed: () {
            if (service.text.trim().isEmpty) return;
            final old = widget.entry;
            Navigator.pop(context, VaultEntry(
              id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
              service: service.text.trim(), username: username.text.trim(), email: email.text.trim(),
              phone: phone.text.trim(), password: password.text, website: website.text.trim(),
              category: category, notes: notes.text.trim(),
            ));
          },
          child: Text(t('Save securely', 'حفظ بأمان')),
        ),
      ],
    );
  }
}
