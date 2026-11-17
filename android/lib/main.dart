import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/store_provider.dart';
import 'providers/web_orders_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian date & currency formatting locale
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormatting init warning: $e');
  }

  // Prevent gray screen of death by replacing Flutter's default ErrorWidget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Terjadi Kendala Tampilan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Initialize Supabase Cloud
  await SupabaseService.initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const SantosaPosApp());
}

class SantosaPosApp extends StatelessWidget {
  const SantosaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => WebOrdersProvider()),
      ],
      child: MaterialApp(
        title: 'Santosa Farma POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                backgroundColor: Color(0xFFF8FAFC),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF059669)),
                ),
              );
            }
            if (auth.isAuthenticated) {
              return const MainNavigationScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
