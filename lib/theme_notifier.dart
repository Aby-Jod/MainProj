import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // Default colors
  Color _textColor = Colors.white;
  Color _backgroundColor = Colors.black;

  // ignore: non_constant_identifier_names
  ThemeNotifier() {
    _loadFromPrefs();
  }

  Color get textColor => _textColor;
  Color get backgroundColor => _backgroundColor;

  Future<void> _loadFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int textColorValue = prefs.getInt('textColor') ?? Colors.white.value;
    int bgColorValue = prefs.getInt('bgColor') ?? Colors.black.value;
    _textColor = Color(textColorValue);
    _backgroundColor = Color(bgColorValue);
    notifyListeners();
  }

  Future<void> setTextColor(Color color) async {
    _textColor = color;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('textColor', color.value);
  }

  Future<void> setBackgroundColor(Color color) async {
    _backgroundColor = color;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bgColor', color.value);
  }
}
