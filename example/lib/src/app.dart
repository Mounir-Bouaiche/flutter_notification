import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:notifications/notification.dart';

import 'sample_feature/sample_item_details_view.dart';
import 'sample_feature/sample_item_list_view.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';

part 'router.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
    required this.settingsController,
  }) : super(key: key);

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    // Glue the SettingsController to the MaterialApp.
    //
    // The AnimatedBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

    print('Entering');

    final initialRoute = Completer<String>();

    NotificationService.instance.onTap((payload) {
      print('Received Payload $payload');
      _nav.currentState?.pushNamed(SampleItemDetailsView.routeName);
      if (!initialRoute.isCompleted) {
        initialRoute
            .complete(payload == null ? '/' : SampleItemDetailsView.routeName);
      }
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) {
          return const SampleItemListView();
        },
      ),
    );

    print(initialRoute);

    return AnimatedBuilder(
      animation: settingsController,
      builder: (BuildContext context, Widget? child) {
        return FutureBuilder<String>(
          future: initialRoute.future,
          builder: (_, initial) {
            if (!initial.hasData) return const SizedBox.shrink();
            return MaterialApp.router(
              routeInformationParser: _router.routeInformationParser,
              routeInformationProvider: _router.routeInformationProvider,
              routerDelegate: _router.routerDelegate,

              // Providing a restorationScopeId allows the Navigator built by the
              // MaterialApp to restore the navigation stack when a user leaves and
              // returns to the app after it has been killed while running in the
              // background.
              restorationScopeId: 'app',

              // Provide the generated AppLocalizations to the MaterialApp. This
              // allows descendant Widgets to display the correct translations
              // depending on the user's locale.
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                // Locale('en', ''), // English, no country code
                Locale('fr', 'FR'),
                Locale('ar', 'MA'),
              ],

              locale: settingsController.locale,

              // Use AppLocalizations to configure the correct application title
              // depending on the user's locale.
              //
              // The appTitle is defined in .arb files found in the localization
              // directory.
              onGenerateTitle: (BuildContext context) => context.tr.appTitle,

              // Define a light and dark color theme. Then, read the user's
              // preferred ThemeMode (light, dark, or system default) from the
              // SettingsController to display the correct theme.
              theme: ThemeData(),
              darkTheme: ThemeData.dark(),
              themeMode: settingsController.themeMode,
            );
          },
        );
      },
    );
  }
}

extension LocalizationExt on BuildContext {
  AppLocalizations get tr => AppLocalizations.of(this)!;
}
