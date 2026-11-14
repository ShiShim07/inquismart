// ─────────────────────────────────────────────────────────────────────────────
// InquiBot — Revised Capstone
// Title: Customer Helpdesk System for NAN CS
//        with Predictive Inquiry Recommendation and Service Analytics
//
// UPDATE: Role-based access control added.
//         Admin/Staff accounts are blocked from the mobile app on login.
//         Only 'customer' role can access the app.
//         Role is saved to SharedPreferences after login.
//         A guard helper (_requireCustomer) is also available for deep checks.
//
// FIX: isFallback flag now reconstructed from message text on history load
//      so "Submit a Ticket" button persists after navigating back.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────
class AppColors {
  static const primary        = Color(0xFF1549A3);
  static const primaryLight   = Color(0xFF1B5FC4);
  static const primarySurface = Color(0xFFE8F0FD);
  static const success        = Color(0xFF3B6D11);
  static const successSurface = Color(0xFFEAF3DE);
  static const warning        = Color(0xFF854F0B);
  static const warningSurface = Color(0xFFFAEEDA);
  static const danger         = Color(0xFFA32D2D);
  static const dangerSurface  = Color(0xFFFCEBEB);
  static const teal           = Color(0xFF0F6E56);
  static const tealSurface    = Color(0xFFE1F5EE);
  static const purple         = Color(0xFF534AB7);
  static const purpleSurface  = Color(0xFFEEEDFE);
  static const surface        = Color(0xFFF4F6FB);
  static const card           = Color(0xFFFFFFFF);
  static const textPrimary    = Color(0xFF1A1A2E);
  static const textSecondary  = Color(0xFF6B7280);
  static const textTertiary   = Color(0xFF9CA3AF);
  static const border         = Color(0xFFE5E7EB);
}

class AppTextStyles {
  static const displayMd  = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.3);
  static const headingLg  = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const headingMd  = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const headingSm  = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const bodyLg     = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.6);
  static const bodyMd     = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5);
  static const bodySm     = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5);
  static const labelMd    = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
  static const labelSm    = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
  static const caption    = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary);
}

// ─────────────────────────────────────────
// API SERVICE
// ─────────────────────────────────────────
class ApiService {
  static const String baseUrl = 'https://kiwi-aide-boogieman.ngrok-free.dev/api';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<http.Response> login(String email, String password) =>
      http.post(Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}));

  static Future<http.Response> register(Map<String, String> data) =>
      http.post(Uri.parse('$baseUrl/register'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(data));

  // Tickets
  static Future<http.Response> getTickets() async =>
      http.get(Uri.parse('$baseUrl/tickets'), headers: await _headers());

  static Future<http.Response> createTicket(String subject, String description) async =>
      http.post(Uri.parse('$baseUrl/tickets'),
          headers: await _headers(),
          body: jsonEncode({'subject': subject, 'description': description}));

  // Chatbot
  static Future<http.Response> sendChatMessage(String message) async =>
      http.post(Uri.parse('$baseUrl/chatbot/message'),
          headers: await _headers(),
          body: jsonEncode({'message': message}));

  static Future<http.Response> getChatHistory() async =>
      http.get(Uri.parse('$baseUrl/chatbot/history'), headers: await _headers());

  static Future<http.Response> clearChatHistory() async =>
      http.delete(Uri.parse('$baseUrl/chatbot/clear'), headers: await _headers());

  // Predictive inquiry
  static Future<http.Response> getInquirySuggestions(String text) async =>
      http.post(Uri.parse('$baseUrl/predict/inquiry'),
          headers: await _headers(),
          body: jsonEncode({'text': text}));

  // Notifications
  static Future<http.Response> getNotifications() async =>
      http.get(Uri.parse('$baseUrl/notifications'), headers: await _headers());

  static Future<http.Response> markNotificationRead(int id) async =>
      http.post(Uri.parse('$baseUrl/notifications/$id/mark-read'), headers: await _headers());

  static Future<http.Response> markAllRead() async =>
      http.post(Uri.parse('$baseUrl/notifications/mark-all-read'), headers: await _headers());

  // Analytics
  static Future<http.Response> getAnalyticsOverview() async =>
      http.get(Uri.parse('$baseUrl/admin/analytics/overview'), headers: await _headers());

  static Future<http.Response> getSentimentTrends() async =>
      http.get(Uri.parse('$baseUrl/admin/analytics/sentiment-trends'), headers: await _headers());
}

// ─────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const StatusBadge({super.key, required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─────────────────────────────────────────
// SENTIMENT & STATUS HELPERS
// ─────────────────────────────────────────
Color _sentimentColor(String sentiment) {
  switch (sentiment) {
    case 'Positive':   return AppColors.success;
    case 'Negative':   return AppColors.danger;
    case 'Neutral':    return AppColors.primary;
    case 'Urgent':     return AppColors.danger;
    case 'Frustrated': return AppColors.warning;
    default:           return AppColors.primary;
  }
}

Color _sentimentBg(String sentiment) {
  switch (sentiment) {
    case 'Positive':   return AppColors.successSurface;
    case 'Negative':   return AppColors.dangerSurface;
    case 'Neutral':    return AppColors.primarySurface;
    case 'Urgent':     return AppColors.dangerSurface;
    case 'Frustrated': return AppColors.warningSurface;
    default:           return AppColors.primarySurface;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'Resolved':   return AppColors.success;
    case 'Processing': return AppColors.warning;
    default:           return AppColors.primary;
  }
}

Color _statusBg(String status) {
  switch (status) {
    case 'Resolved':   return AppColors.successSurface;
    case 'Processing': return AppColors.warningSurface;
    default:           return AppColors.primarySurface;
  }
}

// ─────────────────────────────────────────
// ROLE GUARD HELPER
// Returns true if the saved role is 'customer'.
// Call this anywhere in the app to double-check access.
// ─────────────────────────────────────────
Future<bool> _isCustomerRole() async {
  final prefs = await SharedPreferences.getInstance();
  final role  = prefs.getString('user_role') ?? 'customer';
  return role == 'customer';
}

// ─────────────────────────────────────────
// APP ENTRY
// ─────────────────────────────────────────
void main() => runApp(const InquiSmartApp());

class InquiSmartApp extends StatelessWidget {
  const InquiSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InquiBot — Helpdesk NAN CS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
        fontFamily: 'Roboto',
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surface,
      ),
      home: const LoginScreen(),
    );
  }
}

// ─────────────────────────────────────────
// LOGIN SCREEN
// UPDATE: After successful login, the role returned by the API is saved
//         to SharedPreferences. If the role is 'admin' or 'staff', the
//         user is shown an error and is NOT allowed into the app.
//         Only role == 'customer' proceeds to HomeScreen.
// ─────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _isLoading = false;

  InputDecoration _deco(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
    hintText: hint, hintStyle: AppTextStyles.bodySm,
    prefixIcon: Icon(icon, color: AppColors.primary, size: 20), suffixIcon: suffix,
    filled: true, fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );

  void _login() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password.'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res  = await ApiService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        // ── ROLE-BASED ACCESS CONTROL ──────────────────────────────────────
        // Extract the role from the API response.
        // Falls back to 'customer' if the field is missing (safe default).
        final role = (data['user']['role'] ?? 'customer').toString().toLowerCase().trim();

        // Block admin and staff from using the mobile app.
        if (role == 'admin' || role == 'staff') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: const [
                  Icon(Icons.block_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Admin and Staff accounts must use the web portal.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
                backgroundColor: AppColors.danger,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          // Do NOT save token or navigate. Stop here.
          setState(() => _isLoading = false);
          return;
        }
        // ── END ROLE GUARD ─────────────────────────────────────────────────

        // Only reached for role == 'customer'
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token',      data['token']);
        await prefs.setString('user_name',  data['user']['name']);
        await prefs.setString('user_email', data['user']['email'] ?? '');
        await prefs.setString('user_role',  role); // save role for future guards

        if (mounted) {
          Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Login failed'), backgroundColor: AppColors.danger));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection error.'), backgroundColor: AppColors.danger));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 56),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('InquiBot', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('Helpdesk System — NAN Cellphone Shop', style: AppTextStyles.bodySm),
            const SizedBox(height: 40),
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome back', style: AppTextStyles.headingMd),
                const SizedBox(height: 4),
                const Text('Sign in to your account', style: AppTextStyles.bodySm),
                const SizedBox(height: 24),
                const Text('Email address', style: AppTextStyles.labelMd),
                const SizedBox(height: 8),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: AppTextStyles.bodyMd, decoration: _deco('you@email.com', Icons.mail_outline_rounded)),
                const SizedBox(height: 16),
                const Text('Password', style: AppTextStyles.labelMd),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl, obscureText: _obscure, style: AppTextStyles.bodyMd,
                  decoration: _deco('Enter your password', Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textTertiary, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account? ", style: AppTextStyles.bodySm),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Sign Up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ]),
            const SizedBox(height: 40),
          ]),
        ),
      )),
    );
  }
}

// ─────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure   = true;
  bool _isLoading = false;

  InputDecoration _deco(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
    hintText: hint, hintStyle: AppTextStyles.bodySm,
    prefixIcon: Icon(icon, color: AppColors.primary, size: 20), suffixIcon: suffix,
    filled: true, fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );

  void _register() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in all fields.'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.register({
        'name':                  _nameCtrl.text,
        'email':                 _emailCtrl.text,
        'phone':                 _phoneCtrl.text,
        'password':              _passwordCtrl.text,
        'password_confirmation': _passwordCtrl.text,
      });
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created!'), backgroundColor: AppColors.success));
          Navigator.pop(context);
        }
      } else {
        final errors = data['errors'];
        final msg = errors != null ? errors.values.first[0] : (data['message'] ?? 'Registration failed');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: AppColors.danger));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Create account', style: AppTextStyles.displayMd),
            const SizedBox(height: 4),
            const Text('Sign up to get started with InquiBot', style: AppTextStyles.bodySm),
            const SizedBox(height: 28),
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Full Name', style: AppTextStyles.labelMd),
                const SizedBox(height: 8),
                TextField(controller: _nameCtrl, style: AppTextStyles.bodyMd, decoration: _deco('Enter your full name', Icons.person_outline_rounded)),
                const SizedBox(height: 16),
                const Text('Email Address', style: AppTextStyles.labelMd),
                const SizedBox(height: 8),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: AppTextStyles.bodyMd, decoration: _deco('Enter your email', Icons.mail_outline_rounded)),
                const SizedBox(height: 16),
                const Text('Phone Number', style: AppTextStyles.labelMd),
                const SizedBox(height: 8),
                TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: AppTextStyles.bodyMd, decoration: _deco('Enter your phone number', Icons.phone_outlined)),
                const SizedBox(height: 16),
                const Text('Password', style: AppTextStyles.labelMd),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl, obscureText: _obscure, style: AppTextStyles.bodyMd,
                  decoration: _deco('Create a password', Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textTertiary, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      )),
    );
  }
}

// ─────────────────────────────────────────
// HOME SCREEN
// UPDATE: initState now verifies role on load as an extra safety guard.
//         If somehow a non-customer reaches HomeScreen, they are kicked out.
// ─────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName  = 'Customer';
  String _userEmail = '';
  int _unreadCount  = 0;
  List<dynamic> _recentTickets = [];
  bool _loadingTickets = true;

  @override
  void initState() {
    super.initState();
    _guardRole();   // extra safety: kick out non-customers
    _loadUser();
    _fetchUnread();
    _fetchTickets();
  }

  // ── Extra role guard on HomeScreen ──────────────────────────────────────
  // Protects against edge cases (e.g. manually deep-linked or token reuse).
  void _guardRole() async {
    final isCustomer = await _isCustomerRole();
    if (!isCustomer && mounted) {
      await _logout(showMessage: true);
    }
  }

  Future<void> _logout({bool showMessage = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. Please use the web portal.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName  = prefs.getString('user_name')  ?? 'Customer';
      _userEmail = prefs.getString('user_email') ?? '';
    });
  }

  void _fetchUnread() async {
    try {
      final res = await ApiService.getNotifications();
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() => _unreadCount = data.where((n) => n['is_read'] == false || n['is_read'] == 0).length);
      }
    } catch (_) {}
  }

  void _fetchTickets() async {
    try {
      final res = await ApiService.getTickets();
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) setState(() { _recentTickets = data.take(3).toList(); _loadingTickets = false; });
      } else {
        if (mounted) setState(() => _loadingTickets = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
            child: Center(child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary))),
          ),
          const SizedBox(height: 14),
          Text(_userName, style: AppTextStyles.headingMd),
          const SizedBox(height: 4),
          Text(_userEmail, style: AppTextStyles.bodySm),
          const SizedBox(height: 8),
          const StatusBadge(label: 'Customer', color: AppColors.primary, bgColor: AppColors.primarySurface),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerSurface, foregroundColor: AppColors.danger, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.support_agent_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text('InquiBot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3)),
        ]),
        actions: [
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                _fetchUnread();
              },
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Center(child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                ),
              ),
          ]),
          GestureDetector(
            onTap: _showProfile,
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3))),
              child: Center(child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { _fetchTickets(); _fetchUnread(); },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, $_userName 👋', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('How can we help today?', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5)),
                  child: const Row(children: [
                    Icon(Icons.storefront_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text('NAN Cellphone Shop — Greenhills', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Quick Actions', style: AppTextStyles.headingSm),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _QuickActionCard(
                    icon: Icons.smart_toy_rounded,
                    label: 'Chatbot',
                    color: AppColors.teal,
                    bg: AppColors.tealSurface,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickActionCard(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Submit Ticket',
                    color: AppColors.primary,
                    bg: AppColors.primarySurface,
                    onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmitTicketScreen())); _fetchTickets(); },
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _QuickActionCard(
                    icon: Icons.checklist_rounded,
                    label: 'My Tickets',
                    color: AppColors.purple,
                    bg: AppColors.purpleSurface,
                    onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen())); _fetchTickets(); },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickActionCard(
                    icon: Icons.help_outline_rounded,
                    label: 'FAQ',
                    color: AppColors.warning,
                    bg: AppColors.warningSurface,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen())),
                  )),
                ]),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Tickets', style: AppTextStyles.headingSm),
                    TextButton(
                      onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen())); _fetchTickets(); },
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('See All', style: AppTextStyles.labelMd),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingTickets)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary)))
                else if (_recentTickets.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(children: [
                      Container(width: 56, height: 56, decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 28)),
                      const SizedBox(height: 10),
                      const Text('No tickets yet', style: AppTextStyles.bodySm),
                    ]),
                  ))
                else
                  ...(_recentTickets.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TicketCard(
                      ticketId: '#TKT-${t['id'].toString().padLeft(3, '0')}',
                      subject: t['subject'] ?? '',
                      status: t['status'] ?? 'Pending',
                      date: t['created_at']?.substring(0, 10) ?? '',
                      sentiment: t['sentiment'] ?? 'Neutral',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailScreen(
                        ticketId: '#TKT-${t['id'].toString().padLeft(3, '0')}',
                        subject: t['subject'] ?? '',
                        status: t['status'] ?? 'Pending',
                        date: t['created_at']?.substring(0, 10) ?? '',
                        sentiment: t['sentiment'] ?? 'Neutral',
                        description: t['description'] ?? '',
                        response: t['staff_response'] ?? '',
                      ))),
                    ),
                  ))),
                const SizedBox(height: 32),
              ]),
            ),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.smart_toy_rounded),
        label: const Text('Ask Bot', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    ),
  );
}

class _TicketCard extends StatelessWidget {
  final String ticketId, subject, status, date, sentiment;
  final VoidCallback onTap;
  const _TicketCard({required this.ticketId, required this.subject, required this.status, required this.date, required this.sentiment, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.confirmation_number_outlined, color: _statusColor(status), size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(ticketId, style: AppTextStyles.caption),
          StatusBadge(label: sentiment, color: _sentimentColor(sentiment), bgColor: _sentimentBg(sentiment)),
        ]),
        const SizedBox(height: 4),
        Text(subject, style: AppTextStyles.headingSm, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(date, style: AppTextStyles.caption),
          StatusBadge(label: status, color: _statusColor(status), bgColor: _statusBg(status)),
        ]),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────
// CHATBOT SCREEN
// FIX: _isFallbackText() detects fallback messages by content
//      so the Submit Ticket button is restored when history loads.
// ─────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping       = false;
  bool _loadingHistory = true;

  final List<String> _quickReplies = [
    'What is the warranty period?',
    'How do I track my repair?',
    'What payment methods do you accept?',
    'Where is NAN CS located?',
    'How do I return a product?',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _isFallbackText(String text) {
    final t = text.toLowerCase();
    return t.contains('submit a support ticket') ||
           t.contains('submit a ticket') ||
           t.contains('submit a concern') ||
           t.contains("i'm not sure about that yet") ||
           t.contains("not sure about that") ||
           t.contains('support ticket') ||
           t.contains('our staff will get back to you');
  }

  void _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService.getChatHistory();
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final List<_ChatMessage> loaded = data.map((m) {
          final rawTime = (m['created_at'] ?? '').toString();
          final time    = rawTime.length >= 16 ? rawTime.substring(11, 16) : _now();
          final isUser  = m['role'] == 'user';
          final text    = m['message'] ?? '';
          final isFallback = !isUser && _isFallbackText(text);
          return _ChatMessage(text: text, isUser: isUser, isFallback: isFallback, time: time);
        }).toList();

        if (mounted) {
          setState(() {
            _loadingHistory = false;
            _messages.clear();
            if (loaded.isEmpty) { _addGreeting(); } else { _messages.addAll(loaded); }
          });
          _scrollToBottom();
        }
      } else {
        _showGreeting();
      }
    } catch (_) {
      _showGreeting();
    }
  }

  void _addGreeting() {
    _messages.add(_ChatMessage(
      text: 'Hello! 👋 I\'m InquiBot, the NAN Cellphone Shop assistant. How can I help you today?\n\nYou can ask me about warranties, repairs, payments, or submit a ticket.',
      isUser: false, isFallback: false, time: _now(),
    ));
  }

  void _showGreeting() {
    if (mounted) setState(() { _loadingHistory = false; if (_messages.isEmpty) _addGreeting(); });
  }

  String _now() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _send([String? override]) async {
    final text = (override ?? _msgCtrl.text).trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, isFallback: false, time: _now()));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final res  = await ApiService.sendChatMessage(text);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final reply      = data['reply'] ?? data['message'] ?? 'I received your message.';
        final isFallback = data['intent'] == 'fallback' || _isFallbackText(reply);
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(_ChatMessage(text: reply, isUser: false, isFallback: isFallback, time: _now()));
          });
        }
      } else {
        final result = _localFallback(text);
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(_ChatMessage(text: result.text, isUser: false, isFallback: result.isFallback, time: _now()));
          });
        }
      }
    } catch (_) {
      final result = _localFallback(text);
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(text: result.text, isUser: false, isFallback: result.isFallback, time: _now()));
        });
      }
    }
    _scrollToBottom();
  }

  ({String text, bool isFallback}) _localFallback(String input) {
    final q = input.toLowerCase();
    if (q.contains('warrant')) return (text: 'iPhones come with a 1-year manufacturer warranty covering hardware defects. For Samsung, the warranty is also 1 year. Accidental damage is not covered unless you have extended coverage.', isFallback: false);
    if (q.contains('repair') || q.contains('fix')) return (text: 'Minor repairs (screen, battery) typically take 1–2 hours. Major repairs (motherboard) may take 1–3 business days. You can track your repair status under My Tickets.', isFallback: false);
    if (q.contains('payment') || q.contains('pay') || q.contains('gcash') || q.contains('cash')) return (text: 'We accept Cash, GCash, Maya, and all major credit/debit cards. 0% installment is available for purchases of PHP 5,000+ via BDO, BPI, and Metrobank.', isFallback: false);
    if (q.contains('locat') || q.contains('address') || q.contains('where')) return (text: 'NAN Cellphone Shop is located at 2nd Floor, Greenhills Shopping Center, San Juan City, Metro Manila. We are open Monday to Sunday, 10:00 AM – 8:00 PM.', isFallback: false);
    if (q.contains('return') || q.contains('refund')) return (text: 'We accept returns within 7 days of purchase with the original receipt and complete packaging. The item must be in original condition with no physical damage.', isFallback: false);
    if (q.contains('samsung') || q.contains('iphone') || q.contains('stock') || q.contains('unit')) return (text: 'We carry the latest iPhone and Samsung Galaxy lineup. Stocks vary — message us or visit the shop for current availability. We also have AirPods, accessories, and more!', isFallback: false);
    if (q.contains('install') || q.contains('plan')) return (text: 'Yes! We offer 0% installment via BDO, BPI, and Metrobank for purchases of PHP 5,000 and above. Bring a valid ID and credit card.', isFallback: false);
    if (q.contains('trade') || q.contains('second') || q.contains('buy')) return (text: 'We accept trade-ins! Bring your unit to the shop for evaluation. We will give you the best buy-back price based on its condition.', isFallback: false);
    if (q.contains('ticket') || q.contains('concern') || q.contains('complain')) return (text: 'To submit a concern, tap the button below. Our staff will respond within 24 hours. You can track status under My Tickets.', isFallback: true);
    if (q.contains('hello') || q.contains('hi') || q.contains('hey')) return (text: 'Hi there! 😊 How can I assist you today? Feel free to ask about warranties, repairs, payments, or anything about NAN Cellphone Shop.', isFallback: false);
    return (text: 'I\'m not sure about that yet. 🤔\n\nFor further assistance, you can submit a support ticket and our staff will get back to you within 24 hours.', isFallback: true);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Row(children: [
          CircleAvatar(radius: 15, backgroundColor: Colors.white24, child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16)),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('InquiBot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('NAN CS Assistant', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ]),
        elevation: 0,
      ),
      body: Column(children: [
        if (_loadingHistory)
          const Expanded(
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: AppColors.teal),
              SizedBox(height: 12),
              Text('Loading chat history...', style: AppTextStyles.bodySm),
            ])),
          )
        else ...[
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) return _TypingBubble();
                return _ChatBubble(
                  message: _messages[i],
                  onSubmitTicket: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmitTicketScreen())),
                );
              },
            ),
          ),
          if (_messages.length <= 2)
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickReplies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _send(_quickReplies[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tealSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.teal.withOpacity(0.3), width: 0.5),
                    ),
                    child: Text(_quickReplies[i], style: const TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: AppTextStyles.bodyMd,
                    maxLines: 3, minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: AppTextStyles.bodySm,
                      filled: true, fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ChatMessage {
  final String text, time;
  final bool isUser;
  final bool isFallback;
  _ChatMessage({required this.text, required this.isUser, required this.isFallback, required this.time});
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onSubmitTicket;
  const _ChatBubble({required this.message, this.onSubmitTicket});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: AppColors.tealSurface, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.teal, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser ? null : Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _boldText(
                        message.text,
                        style: TextStyle(fontSize: 14, height: 1.5, color: isUser ? Colors.white : AppColors.textPrimary),
                      ),
                      if (!isUser && message.isFallback) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onSubmitTicket,
                            icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                            label: const Text('Submit a Ticket', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(message.time, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

Widget _boldText(String text, {required TextStyle style}) {
  final spans = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    spans.add(TextSpan(
      text: parts[i],
      style: i.isOdd ? style.copyWith(fontWeight: FontWeight.w700) : style,
    ));
  }
  return Text.rich(TextSpan(children: spans));
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.tealSurface, shape: BoxShape.circle), child: const Icon(Icons.smart_toy_rounded, color: AppColors.teal, size: 18)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)), border: Border.all(color: AppColors.border, width: 0.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0),
            const SizedBox(width: 4),
            _Dot(delay: 200),
            const SizedBox(width: 4),
            _Dot(delay: 400),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.textTertiary, shape: BoxShape.circle)),
  );
}

// ─────────────────────────────────────────
// SUBMIT TICKET SCREEN
// ─────────────────────────────────────────
class SubmitTicketScreen extends StatefulWidget {
  const SubmitTicketScreen({super.key});
  @override
  State<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<SubmitTicketScreen> {
  final _subjectCtrl     = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isLoading = false;
  List<String> _suggestions = [];
  bool _loadingSuggestions = false;

  void _onDescriptionChanged(String value) async {
    if (value.length < 8) { setState(() => _suggestions = []); return; }
    setState(() => _loadingSuggestions = true);
    try {
      final res = await ApiService.getInquirySuggestions(value);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<String>.from(data['suggestions'] ?? []);
        if (mounted) setState(() { _suggestions = list.take(3).toList(); _loadingSuggestions = false; });
      } else {
        if (mounted) setState(() { _suggestions = _localSuggest(value); _loadingSuggestions = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _suggestions = _localSuggest(value); _loadingSuggestions = false; });
    }
  }

  List<String> _localSuggest(String text) {
    final t = text.toLowerCase();
    final List<String> s = [];
    if (t.contains('warrant')) s.add('Check our FAQ on warranty coverage');
    if (t.contains('repair') || t.contains('fix')) s.add('Track your repair under My Tickets');
    if (t.contains('payment') || t.contains('pay')) s.add('View accepted payment methods in FAQ');
    if (t.contains('return') || t.contains('refund')) s.add('Read the 7-day return policy in FAQ');
    if (t.contains('install')) s.add('Ask about 0% installment plans');
    return s.take(3).toList();
  }

  void _submitTicket() async {
    if (_subjectCtrl.text.isEmpty || _descriptionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields.'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.createTicket(_subjectCtrl.text, _descriptionCtrl.text);
      if (res.statusCode == 201) {
        if (mounted) {
          showDialog(context: context, builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: const BoxDecoration(color: AppColors.successSurface, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: AppColors.success, size: 30)),
              const SizedBox(height: 16),
              const Text('Ticket submitted!', style: AppTextStyles.headingMd),
              const SizedBox(height: 8),
              const Text('Our staff will respond within 24 hours. You can track it under My Tickets.', style: AppTextStyles.bodySm, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                child: const Text('Done'),
              )),
            ]),
          ));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit ticket.'), backgroundColor: AppColors.danger));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection error.'), backgroundColor: AppColors.danger));
    }
    setState(() => _isLoading = false);
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint, hintStyle: AppTextStyles.bodySm,
    filled: true, fillColor: AppColors.card,
    contentPadding: const EdgeInsets.all(14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Submit a Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Subject', style: AppTextStyles.labelMd),
          const SizedBox(height: 8),
          TextField(controller: _subjectCtrl, style: AppTextStyles.bodyMd, decoration: _deco('e.g. iPhone 15 warranty question')),
          const SizedBox(height: 18),
          const Text('Describe your concern', style: AppTextStyles.labelMd),
          const SizedBox(height: 8),
          TextField(controller: _descriptionCtrl, maxLines: 5, onChanged: _onDescriptionChanged, style: AppTextStyles.bodyMd, decoration: _deco('Type your concern here...')),
          if (_loadingSuggestions)
            const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.purple, strokeWidth: 2))))
          else if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.purpleSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.purple.withOpacity(0.25), width: 0.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.purple, size: 16),
                  SizedBox(width: 6),
                  Text('Predictive suggestions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.purple)),
                ]),
                const SizedBox(height: 10),
                ..._suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border, width: 0.5)),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_outline_rounded, color: AppColors.purple, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s, style: AppTextStyles.labelMd)),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
                      ]),
                    ),
                  ),
                )),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitTicket,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Submit Ticket', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TICKET DETAIL SCREEN
// ─────────────────────────────────────────
class TicketDetailScreen extends StatelessWidget {
  final String ticketId, subject, status, date, sentiment, description, response;
  const TicketDetailScreen({super.key, required this.ticketId, required this.subject, required this.status, required this.date, required this.sentiment, required this.description, required this.response});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      title: const Text('Ticket Detail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      elevation: 0,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(ticketId, style: AppTextStyles.labelSm),
            StatusBadge(label: status, color: _statusColor(status), bgColor: _statusBg(status)),
          ]),
          const SizedBox(height: 10),
          Text(subject, style: AppTextStyles.headingLg),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(date, style: AppTextStyles.caption),
            const SizedBox(width: 12),
            StatusBadge(label: sentiment, color: _sentimentColor(sentiment), bgColor: _sentimentBg(sentiment)),
          ]),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.person_rounded, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('Your message', style: AppTextStyles.headingSm)]),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)), child: Text(description, style: AppTextStyles.bodyMd)),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.headset_mic_rounded, color: AppColors.teal, size: 18), SizedBox(width: 8), Text('Staff response', style: AppTextStyles.headingSm)]),
          const SizedBox(height: 12),
          response.isEmpty
              ? Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 0.5)),
                  child: const Row(children: [Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 16), SizedBox(width: 8), Expanded(child: Text('Our staff is reviewing your concern. Please wait.', style: TextStyle(fontSize: 13, color: AppColors.warning, height: 1.5)))]))
              : Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.successSurface, borderRadius: BorderRadius.circular(10)), child: Text(response, style: AppTextStyles.bodyMd)),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ticket progress', style: AppTextStyles.headingSm),
          const SizedBox(height: 16),
          _ProgressStep(label: 'Submitted', isCompleted: true, isActive: false),
          _ProgressStep(label: 'Processing', isCompleted: status == 'Processing' || status == 'Resolved', isActive: status == 'Processing'),
          _ProgressStep(label: 'Resolved', isCompleted: status == 'Resolved', isActive: status == 'Resolved', isLast: true),
        ])),
        const SizedBox(height: 30),
      ]),
    ),
  );
}

class _ProgressStep extends StatelessWidget {
  final String label;
  final bool isCompleted, isActive, isLast;
  const _ProgressStep({required this.label, required this.isCompleted, required this.isActive, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? AppColors.success : isActive ? AppColors.primary : AppColors.border;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(isCompleted ? Icons.check_rounded : Icons.circle, color: Colors.white, size: 14)),
        if (!isLast) Container(width: 2, height: 28, color: isCompleted ? AppColors.success.withOpacity(0.4) : AppColors.border),
      ]),
      const SizedBox(width: 12),
      Padding(padding: const EdgeInsets.only(top: 5), child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isCompleted ? AppColors.success : isActive ? AppColors.primary : AppColors.textTertiary))),
    ]);
  }
}

// ─────────────────────────────────────────
// MY TICKETS SCREEN
// ─────────────────────────────────────────
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});
  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  void _fetch() async {
    try {
      final res = await ApiService.getTickets();
      if (res.statusCode == 200) setState(() { _tickets = jsonDecode(res.body); _isLoading = false; });
      else setState(() => _isLoading = false);
    } catch (_) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      title: const Text('My Tickets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      elevation: 0,
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: () { setState(() => _isLoading = true); _fetch(); })],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _tickets.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 36)),
                const SizedBox(height: 14),
                const Text('No tickets yet', style: AppTextStyles.headingSm),
                const SizedBox(height: 4),
                const Text('Your submitted tickets will appear here', style: AppTextStyles.bodySm),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _tickets.length,
                itemBuilder: (_, i) {
                  final t = _tickets[i];
                  final status    = t['status']    ?? 'Pending';
                  final sentiment = t['sentiment'] ?? 'Neutral';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TicketCard(
                      ticketId: '#TKT-${t['id'].toString().padLeft(3, '0')}',
                      subject: t['subject'] ?? '',
                      status: status,
                      date: t['created_at']?.substring(0, 10) ?? '',
                      sentiment: sentiment,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketDetailScreen(
                        ticketId: '#TKT-${t['id'].toString().padLeft(3, '0')}',
                        subject: t['subject'] ?? '',
                        status: status,
                        date: t['created_at']?.substring(0, 10) ?? '',
                        sentiment: sentiment,
                        description: t['description'] ?? '',
                        response: t['staff_response'] ?? '',
                      ))),
                    ),
                  );
                },
              ),
  );
}

// ─────────────────────────────────────────
// NOTIFICATIONS SCREEN
// ─────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifs = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  void _fetch() async {
    try {
      final res = await ApiService.getNotifications();
      if (res.statusCode == 200) setState(() { _notifs = jsonDecode(res.body); _isLoading = false; });
      else setState(() => _isLoading = false);
    } catch (_) { setState(() => _isLoading = false); }
  }

  void _markAll() async {
    try {
      await ApiService.markAllRead();
      setState(() { for (var n in _notifs) n['is_read'] = true; });
    } catch (_) {}
  }

  IconData _icon(String? t) {
    switch (t) {
      case 'ticket_resolved':   return Icons.check_circle_outline_rounded;
      case 'ticket_processing': return Icons.pending_outlined;
      case 'ticket_received':   return Icons.confirmation_number_outlined;
      default:                  return Icons.notifications_none_rounded;
    }
  }

  Color _color(String? t) {
    switch (t) {
      case 'ticket_resolved':   return AppColors.success;
      case 'ticket_processing': return AppColors.warning;
      default:                  return AppColors.primary;
    }
  }

  Color _colorBg(String? t) {
    switch (t) {
      case 'ticket_resolved':   return AppColors.successSurface;
      case 'ticket_processing': return AppColors.warningSurface;
      default:                  return AppColors.primarySurface;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      elevation: 0,
      actions: [TextButton(onPressed: _markAll, child: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 13)))],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _notifs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle), child: const Icon(Icons.notifications_off_outlined, color: AppColors.textTertiary, size: 36)),
                const SizedBox(height: 14),
                const Text('No notifications', style: AppTextStyles.headingSm),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _notifs.length,
                itemBuilder: (_, i) {
                  final n      = _notifs[i];
                  final isRead = n['is_read'] == true || n['is_read'] == 1;
                  final t      = n['type'] as String?;
                  final c = _color(t); final bg = _colorBg(t);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isRead ? AppColors.card : bg,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!isRead) { ApiService.markNotificationRead(n['id']); setState(() => n['is_read'] = true); }
                          showDialog(context: context, builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(children: [Icon(_icon(t), color: c, size: 22), const SizedBox(width: 8), Expanded(child: Text(n['title'] ?? '', style: AppTextStyles.headingSm))]),
                            content: Text(n['message'] ?? '', style: AppTextStyles.bodyMd),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: AppColors.primary)))],
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: isRead ? AppColors.border : c.withOpacity(0.3), width: 0.5)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(_icon(t), color: c, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Expanded(child: Text(n['title'] ?? '', style: TextStyle(fontSize: 14, fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, color: AppColors.textPrimary))),
                                if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                              ]),
                              const SizedBox(height: 4),
                              Text(n['message'] ?? '', style: AppTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(n['created_at']?.toString().substring(0, 10) ?? '', style: AppTextStyles.caption),
                            ])),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
  );
}

// ─────────────────────────────────────────
// FAQ SCREEN
// ─────────────────────────────────────────
class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});
  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  final List<Map<String, String>> _faqs = [
    {'q': 'What is the warranty period for iPhones?',    'a': 'All iPhones come with 1-year manufacturer warranty. Screen damage is not covered unless you have AppleCare+.'},
    {'q': 'Do you accept installment payments?',         'a': 'Yes! 0% installment via BDO, BPI, Metrobank. Minimum PHP 5,000 purchase.'},
    {'q': 'What is your return policy?',                 'a': 'Returns accepted within 7 days with original receipt and complete packaging.'},
    {'q': 'Do you have Samsung Galaxy available?',       'a': 'Yes, we carry the latest Samsung Galaxy lineup. Visit us for current stocks.'},
    {'q': 'How long does repair take?',                  'a': 'Minor repairs: 1–2 hours. Major repairs: 1–3 business days.'},
    {'q': 'Do you buy second-hand phones?',              'a': 'Yes! We accept trade-ins. Bring your unit for evaluation.'},
    {'q': 'What payment methods do you accept?',         'a': 'Cash, GCash, Maya, and all major credit/debit cards.'},
    {'q': 'Do you have AirPods in stock?',               'a': 'Yes! AirPods Pro (2nd gen), AirPods 3rd gen, and AirPods Max.'},
    {'q': 'Where is NAN Cellphone Shop located?',        'a': '2nd Floor, Greenhills Shopping Center, San Juan City, Metro Manila.'},
    {'q': 'What are your store hours?',                  'a': 'Monday to Sunday, 10:00 AM – 8:00 PM.'},
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _faqs.where((f) =>
      f['q']!.toLowerCase().contains(_query.toLowerCase()) ||
      f['a']!.toLowerCase().contains(_query.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('FAQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: AppTextStyles.bodyMd,
              decoration: InputDecoration(
                hintText: 'Search FAQs...', hintStyle: AppTextStyles.bodySm,
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle), child: const Icon(Icons.search_off_rounded, color: AppColors.textTertiary, size: 32)),
              const SizedBox(height: 12),
              const Text('No results found', style: AppTextStyles.headingSm),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final f = filtered[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.card, borderRadius: BorderRadius.circular(16),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
                        child: ExpansionTile(
                          leading: Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle), child: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 18)),
                          title: Text(f['q']!, style: AppTextStyles.labelMd),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)), child: Text(f['a']!, style: AppTextStyles.bodySm)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

