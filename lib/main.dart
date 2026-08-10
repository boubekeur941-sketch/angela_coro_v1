import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mime/mime.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'dart:async';
import 'dart:io';
import 'firebase_options.dart';

import 'app_screens.dart'; // ربط الواجهات

// ============================================================================
// 1. CORE & DEPENDENCY INJECTION
// ============================================================================
final locator = GetIt.instance;

Future<void> setupLocator() async {
  locator.registerLazySingleton<Logger>(() => Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5, lineLength: 50, colors: true, printEmojis: true, printTime: true),
  ));

  final prefs = await SharedPreferences.getInstance();
  locator.registerLazySingleton<SharedPreferences>(() => prefs);

  const secureStorage = FlutterSecureStorage();
  locator.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageAdapter());
  final chatBox = await Hive.openBox<ChatMessage>('chatHistoryBox');
  locator.registerLazySingleton<Box<ChatMessage>>(() => chatBox);

  locator.registerLazySingleton<InternetConnection>(() => InternetConnection());
  locator.registerLazySingleton<AIService>(() => AIService());

  locator.registerLazySingleton<stt.SpeechToText>(() => stt.SpeechToText());
  locator.registerLazySingleton<FlutterTts>(() => FlutterTts());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  await setupLocator();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const AngelaQueenApp(),
    ),
  );
}

// ============================================================================
// 2. CONFIGURATION & MODELS
// ============================================================================
enum AgentType { angela, coro, sandy, pink }

class AngelaPersonality {
  static String userContextMemory = """
  User Name: Pro Member
  Preferences: Prefers clean code, logical structure, and professional UI.
  """;

  static String getPrompt(AgentType agent) {
    String basePrompt = "Always keep the user context in mind: $userContextMemory\n";
    switch (agent) {
      case AgentType.coro:
        return basePrompt + "You are Coro, a Master Programmer and Software Architect.\nExpertise: Flutter, Dart, programming, and system automation.\nProvide optimal, well-documented, and bug-free code. Explain the logic briefly but focus on writing clean code.";
      case AgentType.sandy:
        return basePrompt + "You are Sandy, a Business Strategist and Marketing Expert.\nExpertise: Client negotiations, app scaling, marketing, and digital business.\nProvide professional, structured, and actionable business advice.";
      case AgentType.pink:
        return basePrompt + "You are Pink, an elite Media Producer, UX/UI Expert, and Video Editing Specialist.\nExpertise: Storyboarding, visual aesthetics, video production, and creative direction.\nProvide creative ideas, design suggestions, and media workflows.";
      case AgentType.angela:
      default:
        return basePrompt + "You are Angela Queen, a highly intelligent, precise, and friendly digital platform leader.\nExpertise spans overall digital creation, platform management, and logic.\nProvide insightful advice, and always maintain a professional yet warm tone.";
    }
  }
}

class ChatMessage {
  final String id;
  final ValueNotifier<String> textNotifier;
  final bool isUser;
  final DateTime time;
  bool isError;

  ChatMessage({required this.id, required String text, required this.isUser, required this.time, this.isError = false})
      : textNotifier = ValueNotifier(text);

  String get text => textNotifier.value;
  set text(String val) => textNotifier.value = val;

  void dispose() { textNotifier.dispose(); }

  Map<String, dynamic> toJson() => {"id": id, "text": text, "isUser": isUser, "time": time.toIso8601String(), "isError": isError};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json["id"] ?? Uuid().v4(),
    text: json["text"] ?? "",
    isUser: json["isUser"] ?? false,
    time: DateTime.tryParse(json["time"] ?? "") ?? DateTime.now(),
    isError: json["isError"] ?? false,
  );
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0;

  @override
  ChatMessage read(BinaryReader reader) {
    final map = Map<String, dynamic>.from(reader.readMap());
    return ChatMessage.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer.writeMap(obj.toJson());
  }
}

// ============================================================================
// 3. SERVICES
// ============================================================================
class AIService {
  late GenerativeModel _model;
  ChatSession? _chatSession;
  final _logger = locator<Logger>();
  AgentType _currentAgent = AgentType.angela;

  AIService() {
    _initModel(AgentType.angela);
  }

  void _initModel(AgentType agent) {
    _currentAgent = agent;
    _model = FirebaseVertexAI.instance.generativeModel(
      model: "gemini-2.5-flash",
      systemInstruction: Content.system(AngelaPersonality.getPrompt(agent)),
      generationConfig: GenerationConfig(
        temperature: agent == AgentType.pink ? 0.9 : 0.7,
        topP: 0.9,
        topK: 40,
        maxOutputTokens: 8192,
      ),
    );
  }

  void initSessionWithAgent(AgentType agent, List<Content> history) {
    if (_currentAgent != agent || _chatSession == null) {
      _initModel(agent);
    }
    _chatSession = _model.startChat(history: history);
    _logger.i("AI Chat Session Initialized with agent: ${agent.name}");
  }

  Future<Stream<GenerateContentResponse>> sendMessageStream(String text, {List<XFile>? files}) async {
    if (_chatSession == null) {
      initSessionWithAgent(_currentAgent, []);
    }

    List<Part> parts = [];
    if (text.isNotEmpty) parts.add(TextPart(text));

    if (files != null && files.isNotEmpty) {
      for (var file in files) {
        final bytes = await file.readAsBytes();
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        parts.add(InlineDataPart(mimeType, bytes)); // ✅ تم التصحيح هنا
      }
      return _chatSession!.sendMessageStream(Content.multi(parts));
    } else {
      return _chatSession!.sendMessageStream(Content.text(text));
    }
  }

  Stream<GenerateContentResponse> generateLessonStream(String courseName, String moduleName) {
    final prompt = "You are Angela Queen, an expert instructor. Teach module '$moduleName' of '$courseName'. Format in Markdown.";
    return _model.generateContentStream([Content.text(prompt)]);
  }
}

// ============================================================================
// 4. THEMING & TRANSLATIONS
// ============================================================================
class AngelaColors {
  static const Color background = Color(0xff050505);
  static const Color surface = Color(0xff121212);
  static const Color surfaceLight = Color(0xff1E1E1E);
  static const Color lightBackground = Color(0xffF3F4F6);
  static const Color lightSurface = Color(0xffFFFFFF);
  static const Color lightSurfaceAlt = Color(0xffE5E7EB);
  static const Color primary = Color(0xFFD4AF37);
  static const Color accent = Color(0xFFF3E5AB);
  static const Color error = Color(0xFFEF4444);
  static const Color softText = Color(0xFF9CA3AF);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AngelaColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AngelaColors.primary, brightness: Brightness.dark),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(backgroundColor: AngelaColors.surface, elevation: 1, centerTitle: true),
    cardTheme: CardThemeData(color: AngelaColors.surface, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), // ✅ تم التصحيح هنا
    navigationBarTheme: NavigationBarThemeData(backgroundColor: AngelaColors.surface, indicatorColor: AngelaColors.primary.withOpacity(0.2)),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: AngelaColors.surfaceLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AngelaColors.lightBackground,
    colorScheme: ColorScheme.fromSeed(seedColor: AngelaColors.primary, brightness: Brightness.light),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(backgroundColor: AngelaColors.lightSurface, elevation: 1, centerTitle: true, foregroundColor: Colors.black),
    cardTheme: CardThemeData(color: AngelaColors.lightSurface, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), // ✅ تم التصحيح هنا
    navigationBarTheme: NavigationBarThemeData(backgroundColor: AngelaColors.lightSurface, indicatorColor: AngelaColors.primary.withOpacity(0.2)),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: AngelaColors.lightSurfaceAlt, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
  );
}

class AppTranslations {
  static const Map<String, Map<String, String>> dict = {
    'ar': {
      "Control Center": "مركز التحكم", "App Preferences": "تفضيلات التطبيق", "Language": "اللغة",
      "Dark Theme": "الوضع الداكن", "AI Configuration": "إعدادات الذكاء الاصطناعي", "Model Selection": "اختيار النموذج",
      "Clear Chat History": "مسح سجل الدردشة", "Account & Security": "الحساب والأمان", "Privacy Policy": "سياسة الخصوصية",
      "Sign Out": "تسجيل الخروج", "Log out from your account": "تسجيل الخروج من حسابك", "Guest User": "زائر",
      "Not logged in": "غير مسجل الدخول", "Pro Member": "عضوية برو", "Chat AI": "الدردشة",
      "Academy": "الأكاديمية", "Settings": "الإعدادات", "Welcome to Angela AI": "مرحباً بك في ذكاء أنجيلا",
      "Your ultimate learning platform.": "منصتك التعليمية المطلقة.", "Get Started": "ابدأ الآن",
      "Welcome Back": "مرحباً بعودتك", "Join Angela Queen": "انضم إلى أنجيلا كوين",
      "Sign in to access your digital academy.": "سجل الدخول للوصول لأكاديميتك الرقمية.",
      "Create an account to start your journey.": "أنشئ حساباً لتبدأ رحلتك.", "Email Address": "البريد الإلكتروني",
      "Password": "كلمة المرور", "Sign In": "تسجيل الدخول", "Sign Up": "إنشاء حساب",
      "Don't have an account? Sign Up": "ليس لديك حساب؟ أنشئ حساباً", "Already have an account? Sign In": "لديك حساب بالفعل؟ سجل دخول",
      "Ask Angela Queen...": "اسأل أنجيلا كوين...", "Explore Angela Queen's Academy...": "استكشف أكاديمية أنجيلا...",
      "Angela Academy": "أكاديمية أنجيلا", "Angela": "أنجيلا", "Coro": "كورو", "Sandy": "ساندي", "Pink": "بينك"
    },
    'fr': {
      "Control Center": "Centre de contrôle", "App Preferences": "Préférences de l'app", "Language": "Langue",
      "Dark Theme": "Thème sombre", "AI Configuration": "Configuration de l'IA", "Model Selection": "Sélection du modèle",
      "Clear Chat History": "Effacer l'historique", "Account & Security": "Compte et sécurité", "Privacy Policy": "Politique de confidentialité",
      "Sign Out": "Se déconnecter", "Log out from your account": "Déconnectez-vous de votre compte", "Guest User": "Invité",
      "Not logged in": "Non connecté", "Pro Member": "Membre Pro", "Chat AI": "Chat IA",
      "Academy": "Académie", "Settings": "Paramètres", "Welcome to Angela AI": "Bienvenue sur Angela AI",
      "Your ultimate learning platform.": "Votre plateforme d'apprentissage.", "Get Started": "Commencer",
      "Welcome Back": "Bon retour", "Join Angela Queen": "Rejoignez Angela Queen",
      "Sign in to access your digital academy.": "Connectez-vous à votre académie.",
      "Create an account to start your journey.": "Créez un compte pour commencer.", "Email Address": "Adresse e-mail",
      "Password": "Mot de passe", "Sign In": "Se connecter", "Sign Up": "S'inscrire",
      "Don't have an account? Sign Up": "Pas de compte ? S'inscrire", "Already have an account? Sign In": "Déjà un compte ? Se connecter",
      "Ask Angela Queen...": "Demandez à Angela Queen...", "Explore Angela Queen's Academy...": "Explorez l'Académie d'Angela...",
      "Angela Academy": "Académie Angela", "Angela": "Angela", "Coro": "Coro", "Sandy": "Sandy", "Pink": "Pink"
    },
    'es': {
      "Control Center": "Centro de control", "App Preferences": "Preferencias de la app", "Language": "Idioma",
      "Dark Theme": "Tema oscuro", "AI Configuration": "Configuración de IA", "Model Selection": "Selección de modelo",
      "Clear Chat History": "Borrar historial", "Account & Security": "Cuenta y seguridad", "Privacy Policy": "Política de privacidad",
      "Sign Out": "Cerrar sesión", "Log out from your account": "Cerrar sesión de tu cuenta", "Guest User": "Invitado",
      "Not logged in": "No conectado", "Pro Member": "Miembro Pro", "Chat AI": "Chat IA",
      "Academy": "Academia", "Settings": "Ajustes", "Welcome to Angela AI": "Bienvenido a Angela AI",
      "Your ultimate learning platform.": "Tu plataforma de aprendizaje.", "Get Started": "Empezar",
      "Welcome Back": "Bienvenido de nuevo", "Join Angela Queen": "Únete a Angela Queen",
      "Sign in to access your digital academy.": "Inicia sesión en tu academia.",
      "Create an account to start your journey.": "Crea una cuenta para comenzar.", "Email Address": "Correo electrónico",
      "Password": "Contraseña", "Sign In": "Iniciar sesión", "Sign Up": "Regístrate",
      "Don't have an account? Sign Up": "¿No tienes cuenta? Regístrate", "Already have an account? Sign In": "¿Ya tienes cuenta? Inicia sesión",
      "Ask Angela Queen...": "Pregunta a Angela Queen...", "Explore Angela Queen's Academy...": "Explora la Academia Angela...",
      "Angela Academy": "Academia Angela", "Angela": "Angela", "Coro": "Coro", "Sandy": "Sandy", "Pink": "Pink"
    }
  };
}

extension TranslateExtension on String {
  String tr(BuildContext context) {
    final lang = Provider.of<AppSettingsProvider>(context, listen: true).locale.languageCode;
    if (lang == 'en') return this;
    return AppTranslations.dict[lang]?[this] ?? this;
  }
}

// ============================================================================
// 5. STATE MANAGEMENT (PROVIDERS)
// ============================================================================
class AppSettingsProvider extends ChangeNotifier {
  final SharedPreferences prefs = locator<SharedPreferences>();
  late Locale _locale;
  late ThemeMode _themeMode;
  late bool _showOnboarding;

  AppSettingsProvider() {
    _locale = Locale(prefs.getString('app_lang') ?? 'en');
    _showOnboarding = prefs.getBool('show_onboarding') ?? true;
    _themeMode = (prefs.getBool('is_dark') ?? true) ? ThemeMode.dark : ThemeMode.light;
  }

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get showOnboarding => _showOnboarding;

  void setLocale(String langCode) {
    _locale = Locale(langCode);
    prefs.setString('app_lang', langCode);
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    prefs.setBool('is_dark', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await prefs.setBool('show_onboarding', false);
    _showOnboarding = false;
    notifyListeners();
  }
}

class ChatProvider extends ChangeNotifier {
  final Box<ChatMessage> _chatBox = locator<Box<ChatMessage>>();
  final AIService _aiService = locator<AIService>();
  final Logger _logger = locator<Logger>();
  final InternetConnection _internetChecker = locator<InternetConnection>();

  final stt.SpeechToText _speech = locator<stt.SpeechToText>();
  final FlutterTts _tts = locator<FlutterTts>();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isDisposed = false;
  String? _lastFailedMessage;
  StreamSubscription<GenerateContentResponse>? _streamSubscription;

  AgentType _activeAgent = AgentType.angela;
  AgentType get activeAgent => _activeAgent;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get lastFailedMessage => _lastFailedMessage;

  List<XFile> _selectedFiles = [];
  List<XFile> get selectedFiles => _selectedFiles;

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  ChatProvider() {
    _initSystem();
    _initTTS();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _streamSubscription?.cancel();
    _tts.stop();
    for (final m in _messages) { m.dispose(); }
    super.dispose();
  }

  void _initTTS() {
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      _selectedFiles.addAll(images);
      notifyListeners();
    }
  }

  void removeSelectedFile(int index) {
    _selectedFiles.removeAt(index);
    notifyListeners();
  }

  Future<void> toggleListening(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => _logger.i('STT onStatus: $val'),
        onError: (val) => _logger.e('STT onError: $val'),
      );
      if (available) {
        _isListening = true;
        _speech.listen(onResult: (val) {
          controller.text = val.recognizedWords;
        });
        notifyListeners();
      }
    } else {
      _isListening = false;
      _speech.stop();
      notifyListeners();
    }
  }

  Future<void> speakMessage(String text, String langCode) async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      notifyListeners();
      return;
    }

    _isSpeaking = true;
    notifyListeners();

    await _tts.setLanguage(langCode == 'ar' ? 'ar-SA' : 'en-US');

    if (_activeAgent == AgentType.coro) {
      await _tts.setPitch(0.7);
      await _tts.setSpeechRate(0.5);
    } else if (_activeAgent == AgentType.pink) {
      await _tts.setPitch(1.3);
      await _tts.setSpeechRate(0.6);
    } else {
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
    }

    await _tts.speak(text);
  }

  void _initSystem() {
    _loadHistoryFromHive();
    _initChatSession();
  }

  void _loadHistoryFromHive() {
    _messages = _chatBox.values.toList();
  }

  void _saveMessageToHive(ChatMessage msg) {
    _chatBox.put(msg.id, msg);
  }

  void setActiveAgent(AgentType agent) {
    _activeAgent = agent;
    notifyListeners();
    _initChatSession();
  }

  void _initChatSession() {
    List<Content> safeHistory = [];
    String? lastRole;
    List<TextPart> currentParts = [];

    final recentMessages = _messages.length > 40 ? _messages.sublist(_messages.length - 40) : _messages;

    for (var m in recentMessages) {
      if (m.isError) continue;
      String currentRole = m.isUser ? 'user' : 'model';

      if (lastRole == null) {
        lastRole = currentRole;
        currentParts.add(TextPart(m.text));
      } else if (lastRole == currentRole) {
        currentParts.add(TextPart("\n\n${m.text}"));
      } else {
        safeHistory.add(Content(lastRole, List.from(currentParts)));
        lastRole = currentRole;
        currentParts = [TextPart(m.text)];
      }
    }
    if (currentParts.isNotEmpty && lastRole != null) {
      safeHistory.add(Content(lastRole, currentParts));
    }

    try {
      _aiService.initSessionWithAgent(_activeAgent, safeHistory);
    } catch (e) {
      _logger.e("Failed to initialize session.", error: e);
    }
  }

  Future<bool> _hasRealInternet() async {
    try {
      final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return false;
      return await _internetChecker.hasInternetAccess;
    } catch (e) {
      return true;
    }
  }

  String _parseErrorMessage(dynamic error) {
    final errStr = error.toString().toLowerCase();
    if (error is SocketException || errStr.contains('network')) {
      return "Network timeout: Please check your internet connection.";
    } else if (errStr.contains('firebase') || errStr.contains('app check')) {
      return "Authentication Error: Please ensure Firebase is correctly configured.";
    }
    return "An unexpected error occurred. Please try again.";
  }

  Future<void> sendMessageStream(String text, {bool isRetry = false}) async {
    if (_isLoading || _isDisposed || (text.trim().isEmpty && _selectedFiles.isEmpty)) return;

    bool hasInternet = await _hasRealInternet();
    if (!hasInternet) {
      _lastFailedMessage = text;
      _handleError("Network timeout: No internet connection.", aiMessageToUpdate: null);
      return;
    }

    _lastFailedMessage = null;

    final filesToSend = List<XFile>.from(_selectedFiles);
    _selectedFiles.clear();

    if (!isRetry) {
      String displayTxt = text;
      if (filesToSend.isNotEmpty) displayTxt = "[Attached ${filesToSend.length} files]\n" + text;

      final userMsg = ChatMessage(id: Uuid().v4(), text: displayTxt, isUser: true, time: DateTime.now());
      _messages.add(userMsg);
      _saveMessageToHive(userMsg);
    }

    final aiMsg = ChatMessage(id: Uuid().v4(), text: "", isUser: false, time: DateTime.now());
    _messages.add(aiMsg);

    _isLoading = true;
    notifyListeners();

    try {
      final stream = await _aiService.sendMessageStream(text, files: filesToSend);
      String buffer = "";

      _streamSubscription = stream.listen(
            (response) {
          if (_isDisposed) return;
          buffer += response.text ?? "";
          aiMsg.textNotifier.value = buffer;
        },
        onError: (error) {
          _lastFailedMessage = text;
          _handleError(_parseErrorMessage(error), aiMessageToUpdate: aiMsg);
        },
        onDone: () {
          if (_isDisposed) return;
          _isLoading = false;
          _saveMessageToHive(aiMsg);
          notifyListeners();
        },
      );
    } catch (e) {
      _lastFailedMessage = text;
      _handleError(_parseErrorMessage(e), aiMessageToUpdate: aiMsg);
    }
  }

  void _handleError(String errorMsg, {ChatMessage? aiMessageToUpdate}) {
    if (_isDisposed) return;
    _isLoading = false;
    if (aiMessageToUpdate != null) {
      aiMessageToUpdate.isError = true;
      aiMessageToUpdate.text = errorMsg;
      _saveMessageToHive(aiMessageToUpdate);
    } else {
      final errMsg = ChatMessage(id: Uuid().v4(), text: errorMsg, isUser: false, time: DateTime.now(), isError: true);
      _messages.add(errMsg);
      _saveMessageToHive(errMsg);
    }
    notifyListeners();
  }

  void retryLastMessage() {
    if (_lastFailedMessage != null) {
      String msg = _lastFailedMessage!;
      if (_messages.isNotEmpty && _messages.last.isError) {
        _chatBox.delete(_messages.last.id);
        _messages.removeLast();
      }
      sendMessageStream(msg, isRetry: true);
      notifyListeners();
    }
  }

  void stopGeneration() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isLoading = false;
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      _saveMessageToHive(_messages.last);
    }
    notifyListeners();
  }

  void clearChat() async {
    for (var m in _messages) { m.dispose(); }
    _messages.clear();
    _lastFailedMessage = null;
    await _chatBox.clear();
    _initChatSession();
    notifyListeners();
  }
}