import 'dart:async';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    // For simplicity and speed without code-gen, we use a static map.
    // In a larger production app, this would load JSON files.
    _localizedStrings =
        _staticLocalizedValues[locale.languageCode] ??
        _staticLocalizedValues['en']!;
    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // --- Static Translation Map ---
  static final Map<String, Map<String, String>> _staticLocalizedValues = {
    // English
    'en': {
      'app_title': 'DaktarPai',
      'login_title': 'Welcome Back',
      'login_subtitle': 'Sign in to access your dashboard',
      'login_button': 'Sign In',
      'signup_button': 'Sign Up',
      'email_hint': 'Email Address',
      'password_hint': 'Password',
      'forgot_password': 'Forgot Password?',
      'or_continue_with': 'Or continue with',

      'settings_title': 'Settings',
      'settings_account': 'Account & Security',
      'settings_preferences': 'Preferences',
      'settings_support': 'Support & Legal',

      'tile_notifications': 'Notifications',
      'tile_language': 'Language',
      'tile_currency': 'Currency',
      'tile_appearance': 'Appearance',
      'tile_linked_accounts': 'Linked Accounts',

      'theme_system': 'System Default',
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',

      'select_language': 'Select Language',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'confirm': 'Confirm',
    },
    // Bengali (Bangla)
    'bn': {
      'app_title': 'ডাক্তারপাই',
      'login_title': 'স্বাগতম',
      'login_subtitle': 'আপনার ড্যাশবোর্ডে প্রবেশ করতে সাইন ইন করুন',
      'login_button': 'সাইন ইন',
      'signup_button': 'সাইন আপ',
      'email_hint': 'ইমেল ঠিকানা',
      'password_hint': 'পাসওয়ার্ড',
      'forgot_password': 'পাসওয়ার্ড भूल গেছেন?',
      'or_continue_with': 'অথবা চালিয়ে যান',

      'settings_title': 'সেটিংস',
      'settings_account': 'অ্যাকাউন্ট এবং সুরক্ষা',
      'settings_preferences': 'পছন্দসমূহ',
      'settings_support': 'সহায়তা এবং আইনি',

      'tile_notifications': 'নোটিফিকেশন',
      'tile_language': 'ভাষা',
      'tile_currency': 'মুদ্রা',
      'tile_appearance': 'চেহারা',
      'tile_linked_accounts': 'লিঙ্কযুক্ত অ্যাকাউন্টস',

      'theme_system': 'সিস্টেম ডিফল্ট',
      'theme_light': 'লাইট মোড',
      'theme_dark': 'ডার্ক মোড',

      'select_language': 'ভাষা নির্বাচন করুন',
      'cancel': 'বাতিল',
      'save': 'সংরক্ষণ',
      'delete': 'মুছুন',
      'confirm': 'নিশ্চিত করুন',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'bn'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
