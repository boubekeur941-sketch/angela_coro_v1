import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:share_plus/share_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';

import 'main.dart'; // استدعاء الأساسيات

class AngelaQueenApp extends StatelessWidget {
  const AngelaQueenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Angela Queen AI",
      themeMode: appSettings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: appSettings.locale,
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: appSettings.showOnboarding ? const OnboardingScreen() : const AngelaSplashScreen(),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AngelaColors.primary.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
              ),
              child: ClipOval(child: Image.asset('assets/19111.jpg', fit: BoxFit.cover)),
            ),
            const SizedBox(height: 30),
            Text("Welcome to Angela AI".tr(context), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Your ultimate learning platform.".tr(context), style: const TextStyle(fontSize: 16, color: AngelaColors.softText)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AngelaColors.primary, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => context.read<AppSettingsProvider>().completeOnboarding(),
              child: Text("Get Started".tr(context), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

class AngelaSplashScreen extends StatefulWidget {
  const AngelaSplashScreen({super.key});
  @override
  State<AngelaSplashScreen> createState() => _AngelaSplashScreenState();
}

class _AngelaSplashScreenState extends State<AngelaSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AngelaColors.primary.withOpacity(0.4), blurRadius: 40, spreadRadius: 5)]),
                  child: ClipOval(child: Image.asset('assets/19111.jpg', width: 160, height: 160, fit: BoxFit.cover)),
                ),
                const SizedBox(height: 30),
                const Text("ANGELA QUEEN", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
                const SizedBox(height: 10),
                const CircularProgressIndicator(color: AngelaColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: const Center(child: CircularProgressIndicator(color: AngelaColors.primary)));
        }
        if (snapshot.hasData) {
          return const AngelaMainNavigation();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error', style: const TextStyle(color: Colors.white)), backgroundColor: AngelaColors.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AngelaColors.primary.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)]),
                child: ClipOval(child: Image.asset('assets/19111.jpg', width: 130, height: 130, fit: BoxFit.cover)),
              ),
              const SizedBox(height: 30),
              Text(
                _isLogin ? 'Welcome Back'.tr(context) : 'Join Angela Queen'.tr(context),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Text(
                _isLogin ? 'Sign in to access your digital academy.'.tr(context) : 'Create an account to start your journey.'.tr(context),
                style: const TextStyle(fontSize: 14, color: AngelaColors.softText),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Email Address'.tr(context),
                  prefixIcon: const Icon(Icons.email_outlined, color: AngelaColors.primary),
                  filled: true,
                  fillColor: isDark ? AngelaColors.surface : AngelaColors.lightSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Password'.tr(context),
                  prefixIcon: const Icon(Icons.lock_outline, color: AngelaColors.primary),
                  filled: true,
                  fillColor: isDark ? AngelaColors.surface : AngelaColors.lightSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AngelaColors.primary, foregroundColor: Colors.white, elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: _isLoading
                      ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isLogin ? 'Sign In'.tr(context) : 'Sign Up'.tr(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? "Don't have an account? Sign Up".tr(context) : "Already have an account? Sign In".tr(context),
                  style: const TextStyle(color: AngelaColors.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const FadeIndexedStack({super.key, required this.index, required this.children});
  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _controller.forward();
  }
  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) _controller.forward(from: 0.0);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _controller, child: IndexedStack(index: widget.index, children: widget.children));
}

class AngelaMainNavigation extends StatefulWidget {
  const AngelaMainNavigation({super.key});
  @override
  State<AngelaMainNavigation> createState() => _AngelaMainNavigationState();
}

class _AngelaMainNavigationState extends State<AngelaMainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    AngelaAIChat(key: ValueKey('chat')),
    InteractiveAngelaAcademy(key: ValueKey('academy')),
    AngelaSettingsScreen(key: ValueKey('settings'))
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeIndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.smart_toy_outlined), selectedIcon: const Icon(Icons.smart_toy), label: "Chat AI".tr(context)),
          NavigationDestination(icon: const Icon(Icons.school_outlined), selectedIcon: const Icon(Icons.school), label: "Academy".tr(context)),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: "Settings".tr(context)),
        ],
      ),
    );
  }
}

class InteractiveAngelaAcademy extends StatefulWidget {
  const InteractiveAngelaAcademy({super.key});
  @override
  State<InteractiveAngelaAcademy> createState() => _InteractiveAngelaAcademyState();
}

class _InteractiveAngelaAcademyState extends State<InteractiveAngelaAcademy> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _academyCourses = [
    {"title": "Mastering Flutter & Dart", "subtitle": "Advanced cross-platform application architecture.", "icon": Icons.code, "color": Colors.blue},
    {"title": "Industrial Automation & Control", "subtitle": "System tuning, logic, and hardware integration.", "icon": Icons.settings_suggest, "color": Colors.orange},
    {"title": "Advanced Logic & Algorithms", "subtitle": "Problem solving and optimal code structuring.", "icon": Icons.psychology, "color": Colors.purple},
    {"title": "Digital App Business", "subtitle": "Scaling, marketing, and client negotiations.", "icon": Icons.trending_up, "color": Colors.teal}
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Angela Academy".tr(context), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Explore Angela Queen's Academy...".tr(context),
                prefixIcon: const Icon(Icons.school, color: AngelaColors.primary),
                filled: true,
                fillColor: isDark ? AngelaColors.background : AngelaColors.lightBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _academyCourses.length,
              itemBuilder: (context, index) {
                final course = _academyCourses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(backgroundColor: course["color"].withOpacity(0.2), child: Icon(course["icon"], color: course["color"])),
                    title: Text(course["title"], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(course["subtitle"], style: const TextStyle(fontSize: 12, color: AngelaColors.softText))),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AngelaColors.softText),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course)));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(course["title"], style: const TextStyle(fontSize: 18)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: CircleAvatar(radius: 50, backgroundColor: course["color"].withOpacity(0.2), child: Icon(course["icon"], size: 50, color: course["color"]))),
            const SizedBox(height: 20),
            Center(child: Text(course["title"], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            const SizedBox(height: 10),
            Center(child: Text(course["subtitle"], style: const TextStyle(fontSize: 16, color: AngelaColors.softText), textAlign: TextAlign.center)),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: AngelaColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => InteractiveLessonScreen(courseTitle: course["title"], moduleTitle: "Introduction & Setup")));
              },
              child: Text("Get Started".tr(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 35),
            const Text("Course Curriculum", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildModuleTile(context, "1", "Introduction & Setup", "15 mins", course["title"]),
            _buildModuleTile(context, "2", "Core Concepts & Logic", "45 mins", course["title"]),
            _buildModuleTile(context, "3", "Advanced Techniques", "1 hr 20 mins", course["title"]),
            _buildModuleTile(context, "4", "Final Project Construction", "2 hrs", course["title"]),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleTile(BuildContext context, String number, String title, String duration, String courseTitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: isDark ? AngelaColors.surfaceLight : AngelaColors.lightSurfaceAlt, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AngelaColors.primary.withOpacity(0.2), child: Text(number, style: const TextStyle(color: AngelaColors.primary, fontWeight: FontWeight.bold))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(duration, style: const TextStyle(color: AngelaColors.softText, fontSize: 12)),
        trailing: const Icon(Icons.play_circle_fill, color: AngelaColors.accent),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => InteractiveLessonScreen(courseTitle: courseTitle, moduleTitle: title)));
        },
      ),
    );
  }
}

class InteractiveLessonScreen extends StatefulWidget {
  final String courseTitle;
  final String moduleTitle;
  const InteractiveLessonScreen({super.key, required this.courseTitle, required this.moduleTitle});

  @override
  State<InteractiveLessonScreen> createState() => _InteractiveLessonScreenState();
}

class _InteractiveLessonScreenState extends State<InteractiveLessonScreen> {
  final ValueNotifier<String> _contentNotifier = ValueNotifier<String>("");
  bool _isLoading = true;
  bool _hasError = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startLessonGeneration();
  }

  void _startLessonGeneration() {
    final aiService = locator<AIService>();
    _isLoading = true;
    _hasError = false;
    _contentNotifier.value = "";
    try {
      final stream = aiService.generateLessonStream(widget.courseTitle, widget.moduleTitle);
      _subscription = stream.listen(
              (response) { _isLoading = false; _contentNotifier.value += response.text ?? ""; },
          onError: (error) { _isLoading = false; _hasError = true; _contentNotifier.value = "Error loading lesson."; },
          onDone: () { _isLoading = false; }
      );
    } catch (e) {
      _isLoading = false; _hasError = true; _contentNotifier.value = "Initialization error.";
    }
  }

  @override
  void dispose() { _subscription?.cancel(); _contentNotifier.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.moduleTitle, style: const TextStyle(fontSize: 16)), elevation: 1),
      body: ValueListenableBuilder<String>(
        valueListenable: _contentNotifier,
        builder: (context, content, child) {
          return Stack(
            children: [
              if (content.isNotEmpty)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: MarkdownBody(
                    data: content,
                    selectable: true,
                    builders: { 'code': CodeElementBuilder(context) },
                    styleSheet: MarkdownStyleSheet(p: const TextStyle(fontSize: 16, height: 1.5), h1: const TextStyle(color: AngelaColors.primary, fontWeight: FontWeight.bold), h2: const TextStyle(color: AngelaColors.accent, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AngelaColors.primary)),
              if (_hasError)
                Center(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AngelaColors.error), icon: const Icon(Icons.refresh, color: Colors.white), label: const Text("Retry Loading", style: TextStyle(color: Colors.white)), onPressed: () { setState(() { _startLessonGeneration(); }); }))
            ],
          );
        },
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeElementBuilder(this.context);
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = (element.attributes['class'] ?? '').replaceFirst('language-', '');
    if (language.isEmpty) language = 'code';
    return Container(
      width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xff282c34), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(color: Color(0xff1e1e24), borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(language.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: () { Clipboard.setData(ClipboardData(text: element.textContent)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!"), duration: Duration(seconds: 1))); },
                  child: const Row(children: [Icon(Icons.copy, size: 14, color: Colors.white70), SizedBox(width: 4), Text("Copy", style: TextStyle(color: Colors.white70, fontSize: 12))]),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: HighlightView(element.textContent, language: language == 'code' ? 'dart' : language, theme: atomOneDarkTheme, padding: EdgeInsets.zero, textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14))),
        ],
      ),
    );
  }
}

class AngelaAIChat extends StatefulWidget {
  const AngelaAIChat({super.key});
  @override
  State<AngelaAIChat> createState() => _AngelaAIChatState();
}

class _AngelaAIChatState extends State<AngelaAIChat> with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _previousMessageCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() { _controller.dispose(); _scrollController.dispose(); super.dispose(); }

  void _scrollToBottom() {
    if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  String _formatTime(DateTime time) { return DateFormat('HH:mm').format(time); }

  Widget _buildAgentChip(BuildContext context, ChatProvider provider, AgentType agent, IconData icon, String label) {
    final isSelected = provider.activeAgent == agent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : AngelaColors.primary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black))),
          ],
        ),
        selected: isSelected,
        selectedColor: AngelaColors.primary,
        backgroundColor: isDark ? AngelaColors.surfaceLight : AngelaColors.lightSurfaceAlt,
        onSelected: (bool selected) {
          if (selected) {
            provider.setActiveAgent(agent);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to $label"), duration: const Duration(milliseconds: 800), backgroundColor: AngelaColors.primary));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chatProvider = context.watch<ChatProvider>();
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (chatProvider.messages.length > _previousMessageCount) {
      _previousMessageCount = chatProvider.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 14, backgroundColor: AngelaColors.primary, child: Icon(Icons.auto_awesome, size: 16, color: Colors.white)), SizedBox(width: 10), Text("Angela AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        actions: [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => context.read<ChatProvider>().clearChat())],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                _buildAgentChip(context, chatProvider, AgentType.angela, Icons.auto_awesome, "Angela".tr(context)),
                _buildAgentChip(context, chatProvider, AgentType.coro, Icons.code, "Coro".tr(context)),
                _buildAgentChip(context, chatProvider, AgentType.sandy, Icons.business_center, "Sandy".tr(context)),
                _buildAgentChip(context, chatProvider, AgentType.pink, Icons.movie_filter, "Pink".tr(context)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: chatProvider.messages.isEmpty ? _buildEmptyState(chatProvider) : ListView.builder(
                controller: _scrollController, padding: const EdgeInsets.all(15), itemCount: chatProvider.messages.length,
                itemBuilder: (context, i) {
                  if (i == chatProvider.messages.length - 1 && chatProvider.isLoading) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300), tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child)),
                    child: _buildBubble(chatProvider.messages[i], isRtl, isDark, key: ValueKey(chatProvider.messages[i].id)),
                  );
                },
              ),
            ),
          ),
          if (chatProvider.isLoading) Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Angela is typing █", style: TextStyle(color: AngelaColors.accent, fontStyle: FontStyle.italic)), TextButton.icon(icon: const Icon(Icons.stop_circle, color: Colors.redAccent), label: const Text("Stop", style: TextStyle(color: Colors.redAccent)), onPressed: () => context.read<ChatProvider>().stopGeneration())])),
          if (chatProvider.lastFailedMessage != null && !chatProvider.isLoading) Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AngelaColors.error), icon: const Icon(Icons.refresh, color: Colors.white), label: const Text("Retry Last Message", style: TextStyle(color: Colors.white)), onPressed: () { context.read<ChatProvider>().retryLastMessage(); WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom()); })),

          if (chatProvider.selectedFiles.isNotEmpty)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: chatProvider.selectedFiles.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0, top: 5.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(chatProvider.selectedFiles[index].path), height: 55, width: 55, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: 2, top: 0,
                        child: InkWell(
                          onTap: () => chatProvider.removeSelectedFile(index),
                          child: const CircleAvatar(radius: 12, backgroundColor: Colors.redAccent, child: Icon(Icons.close, size: 14, color: Colors.white)),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),

          _buildInputArea(context, chatProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ChatProvider provider) {
    String agentName = "Angela Queen";
    String agentDesc = "Your premium digital leader & platform expert.\nHow shall we innovate today?";

    if (provider.activeAgent == AgentType.coro) {
      agentName = "Coro";
      agentDesc = "I write highly optimized, secure, and structured code.\nWhat are we building today?";
    } else if (provider.activeAgent == AgentType.sandy) {
      agentName = "Sandy";
      agentDesc = "Let's scale your ideas into profitable digital assets.\nHow can I assist your business?";
    } else if (provider.activeAgent == AgentType.pink) {
      agentName = "Pink";
      agentDesc = "Creative direction, UI/UX, and visual perfection.\nWhat's the vision?";
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AngelaColors.accent.withOpacity(0.2), blurRadius: 30, spreadRadius: 10)]),
              child: ClipOval(child: Image.asset('assets/19111.jpg', width: 100, height: 100, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 30),
            Text("I am $agentName.", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(agentDesc, style: const TextStyle(fontSize: 16, color: AngelaColors.softText, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: [
                _buildPremiumChip("📱 Flutter Architecture", Icons.phone_android),
                _buildPremiumChip("⚙️ Automation Logic", Icons.settings_suggest),
                _buildPremiumChip("🎬 Media & Storyboarding", Icons.movie_filter),
                _buildPremiumChip("🔍 Debug Android Studio", Icons.bug_report),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumChip(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      elevation: 2, pressElevation: 4, shadowColor: AngelaColors.primary.withOpacity(0.2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), backgroundColor: isDark ? AngelaColors.surfaceLight : AngelaColors.lightSurfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AngelaColors.primary.withOpacity(0.3), width: 1)),
      avatar: Icon(icon, size: 18, color: AngelaColors.accent), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      onPressed: () { _controller.text = label; },
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isRtl, bool isDark, {Key? key}) {
    final bubbleColor = msg.isUser ? AngelaColors.primary : (isDark ? AngelaColors.surfaceLight : AngelaColors.lightSurfaceAlt);
    final textColor = msg.isUser || isDark ? Colors.white : Colors.black87;

    return Padding(
      key: key, padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[const CircleAvatar(radius: 16, backgroundColor: AngelaColors.primary, child: Icon(Icons.auto_awesome, size: 18, color: Colors.white)), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: msg.isError ? AngelaColors.error.withOpacity(0.2) : bubbleColor, border: msg.isError ? Border.all(color: AngelaColors.error) : null,
                    borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: msg.isUser ? (isRtl ? Radius.zero : const Radius.circular(20)) : (isRtl ? const Radius.circular(20) : Radius.zero), bottomRight: msg.isUser ? (isRtl ? const Radius.circular(20) : Radius.zero) : (isRtl ? Radius.zero : const Radius.circular(20))),
                  ),
                  child: Column(
                    crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<String>(valueListenable: msg.textNotifier, builder: (context, text, child) => MarkdownBody(data: text, selectable: true, builders: { 'code': CodeElementBuilder(context) }, styleSheet: MarkdownStyleSheet(p: TextStyle(color: msg.isError ? Colors.redAccent : textColor, fontSize: 16)))),
                      const SizedBox(height: 5),
                      Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatTime(msg.time), style: TextStyle(fontSize: 10, color: msg.isUser ? Colors.white70 : AngelaColors.softText)), if (msg.isUser) ...[const SizedBox(width: 4), Icon(msg.isError ? Icons.error_outline : Icons.done_all, size: 14, color: msg.isError ? Colors.redAccent : Colors.white70)]])
                    ],
                  ),
                ),
                if (!msg.isUser && !msg.isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 5, right: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(onTap: () { Clipboard.setData(ClipboardData(text: msg.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard!"), duration: Duration(seconds: 1))); }, child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 16, color: AngelaColors.softText))),
                        const SizedBox(width: 15),
                        InkWell(onTap: () => Share.share(msg.text), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.share, size: 16, color: AngelaColors.softText))),
                        const SizedBox(width: 15),
                        InkWell(
                            onTap: () {
                              final langCode = Localizations.localeOf(context).languageCode;
                              context.read<ChatProvider>().speakMessage(msg.text, langCode);
                            },
                            child: Padding(padding: const EdgeInsets.all(4), child: Icon(context.watch<ChatProvider>().isSpeaking ? Icons.volume_up : Icons.volume_down, size: 16, color: AngelaColors.softText))
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (msg.isUser) ...[const SizedBox(width: 8), CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade800, child: const Icon(Icons.person, size: 18, color: Colors.white))],
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      decoration: BoxDecoration(color: isDark ? AngelaColors.background : AngelaColors.lightBackground, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)]),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: AngelaColors.softText,
            onPressed: () => provider.pickImage(),
          ),
          Expanded(
              child: TextField(
                  controller: _controller, enabled: !provider.isLoading, textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: provider.isListening ? "Listening..." : "Ask Angela Queen...".tr(context),
                    hintStyle: TextStyle(color: provider.isListening ? AngelaColors.error : AngelaColors.softText),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    filled: true, fillColor: isDark ? AngelaColors.surfaceLight : AngelaColors.lightSurfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(provider.isListening ? Icons.mic : Icons.mic_none),
                      color: provider.isListening ? Colors.redAccent : AngelaColors.primary,
                      onPressed: () => provider.toggleListening(_controller),
                    ),
                  ),
                  onSubmitted: (val) { if(val.trim().isNotEmpty || provider.selectedFiles.isNotEmpty) { provider.sendMessageStream(val.trim()); _controller.clear(); } }
              )
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
              mini: true,
              backgroundColor: provider.isLoading ? Colors.grey : AngelaColors.primary, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onPressed: provider.isLoading ? null : () { if (_controller.text.trim().isNotEmpty || provider.selectedFiles.isNotEmpty) { provider.sendMessageStream(_controller.text.trim()); _controller.clear(); } },
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)
          )
        ],
      ),
    );
  }
}

class AngelaSettingsScreen extends StatelessWidget {
  const AngelaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AppSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Control Center".tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            color: isDark ? AngelaColors.surfaceLight : AngelaColors.lightSurfaceAlt,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(radius: 35, backgroundColor: AngelaColors.primary.withOpacity(0.2), child: const Icon(Icons.person, size: 40, color: AngelaColors.primary)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.email?.split('@')[0] ?? "Guest User".tr(context), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(user?.email ?? "Not logged in".tr(context), style: const TextStyle(color: AngelaColors.softText, fontSize: 14)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AngelaColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: Text("Pro Member".tr(context), style: const TextStyle(color: AngelaColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          Text("App Preferences".tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AngelaColors.primary)),
          const SizedBox(height: 10),
          _buildSettingsTile(
            icon: Icons.language,
            title: "Language".tr(context),
            trailing: DropdownButton<String>(
              underline: const SizedBox(),
              value: settingsProvider.locale.languageCode,
              items: const [
                DropdownMenuItem(value: 'en', child: Text("English", style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'ar', child: Text("العربية", style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'fr', child: Text("Français", style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'es', child: Text("Español", style: TextStyle(fontSize: 14)))
              ],
              onChanged: (val) { if (val != null) settingsProvider.setLocale(val); },
            ),
          ),
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: "Dark Theme".tr(context),
            trailing: Switch(
              value: settingsProvider.themeMode == ThemeMode.dark,
              onChanged: (val) => settingsProvider.toggleTheme(),
              activeColor: AngelaColors.primary,
            ),
          ),

          const SizedBox(height: 20),

          Text("AI Configuration".tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AngelaColors.primary)),
          const SizedBox(height: 10),
          _buildSettingsTile(icon: Icons.memory, title: "Model Selection".tr(context), subtitle: "Gemini 2.5 Flash", onTap: () {}),
          _buildSettingsTile(icon: Icons.history, title: "Clear Chat History".tr(context), onTap: () {
            context.read<ChatProvider>().clearChat();
          }),

          const SizedBox(height: 20),

          Text("Account & Security".tr(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AngelaColors.primary)),
          const SizedBox(height: 10),
          _buildSettingsTile(icon: Icons.privacy_tip_outlined, title: "Privacy Policy".tr(context), onTap: () {}),

          _buildSettingsTile(icon: Icons.logout, title: "Sign Out".tr(context), subtitle: "Log out from your account".tr(context), onTap: () async {
            await FirebaseAuth.instance.signOut();
          }),

          const SizedBox(height: 40),
          const Center(child: Text("Angela Queen App v1.0.0", style: TextStyle(color: AngelaColors.softText, fontSize: 12))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AngelaColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: AngelaColors.primary, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AngelaColors.softText)) : null,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: AngelaColors.softText),
        onTap: onTap,
      ),
    );
  }
}