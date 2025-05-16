import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/add_data_screen.dart';
import 'package:hr/core/app_colors.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Ensure Flutter and EasyLocalization are initialized
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized(); // <-- Add this line

  // Initialize FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/langs', // <-- Make sure this path matches your assets
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('ar'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1280, 720), // Set your design size for Windows
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            SfGlobalLocalizations.delegate,
            EasyLocalization.of(context)!.delegate,
          ],
          supportedLocales: context.supportedLocales,

          locale: context.locale,
          title: 'HR',
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.grey[200],
            appBarTheme: AppBarTheme(backgroundColor: Colors.grey[200]),

            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: AppColors.primaryColor,
              secondary: AppColors.primaryColor,
            ),
            fontFamily: 'Cairo',
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStatePropertyAll<Color>(AppColors.primaryColor),
            ),
          ),
          home: const AddDataScreen(),
        );
      },
    );
  }
}
