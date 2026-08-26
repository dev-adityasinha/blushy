import 'package:flutter/material.dart';

typedef ObjectWidgetBuilder = Widget Function(dynamic content, Color? customColor);

class ObjectRegistry {
  static final ObjectRegistry _instance = ObjectRegistry._internal();
  factory ObjectRegistry() => _instance;
  ObjectRegistry._internal();

  final Map<String, ObjectWidgetBuilder> _builders = {};

  void register(String type, ObjectWidgetBuilder builder) {
    _builders[type.toLowerCase()] = builder;
  }

  Widget buildObject(String type, dynamic content, Color? customColor) {
    final builder = _builders[type.toLowerCase()];
    if (builder != null) {
      return builder(content, customColor);
    }
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(content.toString()),
    );
  }

  bool isRegistered(String type) => _builders.containsKey(type.toLowerCase());
}
