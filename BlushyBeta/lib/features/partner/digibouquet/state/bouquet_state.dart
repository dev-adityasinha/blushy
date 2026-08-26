import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flower.dart';
import '../models/bouquet.dart';
import '../models/profile.dart';

class BouquetState extends ChangeNotifier {
  SharedPreferences? _prefs;

  // General App State
  String _currentStep = 'pick'; // 'pick' | 'arrange' | 'finish'
  String _currentMode = 'color'; // 'color' | 'mono'
  Map<String, int> _selectedFlowers = {}; // flowerId -> count
  List<PlacedFlower> _placedFlowers = [];
  int _greeneryIndex = 0;
  String _wrappingPaper = 'wrap-classic';
  int _ribbonColorIndex = 0;
  String _bouquetMessage = '';
  double _arrangementSeed = 0.5;

  // Profile and community data
  UserProfile? _profile;
  List<Bouquet> _savedBouquets = [];
  Set<String> _likedBouquets = {};
  int _createdBouquetsCount = 0;

  // Undo / Redo Stacks for Picking
  final List<Map<String, int>> _undoStack = [];
  final List<Map<String, int>> _redoStack = [];

  // Ribbon color palettes (Matching premium Blushy / Gold aesthetics)
  static const List<Color> ribbonColors = [
    Color(0xFFD4A574), // Gold
    Color(0xFFE8A0B4), // Pastel Pink
    Color(0xFF8FB996), // Sage Green
    Color(0xFFE2E4E8), // Soft Silver
    Color(0xFF3D232A), // Dark Rose
  ];

  static const List<Map<String, String>> wrappingOptions = [
    {'class': 'wrap-classic', 'label': 'Classic Cream'},
    {'class': 'wrap-rose', 'label': 'Blushing Rose'},
    {'class': 'wrap-sage', 'label': 'Sage Garden'},
    {'class': 'wrap-slate', 'label': 'Midnight Slate'},
    {'class': 'vase-glass', 'label': 'Glass Vase'},
    {'class': 'vase-ceramic', 'label': 'Ceramic Pot'},
  ];

  // Getters
  String get currentStep => _currentStep;
  String get currentMode => _currentMode;
  Map<String, int> get selectedFlowers => _selectedFlowers;
  List<PlacedFlower> get placedFlowers => _placedFlowers;
  int get greeneryIndex => _greeneryIndex;
  String get wrappingPaper => _wrappingPaper;
  int get ribbonColorIndex => _ribbonColorIndex;
  String get bouquetMessage => _bouquetMessage;
  double get arrangementSeed => _arrangementSeed;
  UserProfile? get profile => _profile;
  List<Bouquet> get savedBouquets => _savedBouquets;
  Set<String> get likedBouquets => _likedBouquets;
  int get createdBouquetsCount => _createdBouquetsCount;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get totalFlowersSelected {
    return _selectedFlowers.values.fold(0, (sum, val) => sum + val);
  }

  // Initialization
  BouquetState() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load profile
    final profileStr = _prefs?.getString('user_profile');
    if (profileStr != null) {
      try {
        _profile = UserProfile.fromJson(json.decode(profileStr));
      } catch (_) {}
    }

    // Load saved bouquets
    final bouquetsList = _prefs?.getStringList('saved_bouquets');
    if (bouquetsList != null) {
      _savedBouquets = bouquetsList
          .map((item) {
            try {
              return Bouquet.fromJson(json.decode(item));
            } catch (_) {
              return null;
            }
          })
          .whereType<Bouquet>()
          .toList();
    }

    // Load liked bouquets
    final likedList = _prefs?.getStringList('liked_bouquets');
    if (likedList != null) {
      _likedBouquets = likedList.toSet();
    }

    // Load bouquet count
    _createdBouquetsCount = _prefs?.getInt('created_bouquets_count') ?? 0;

    notifyListeners();
  }

  // Navigation / Step helpers
  void setStep(String step) {
    _currentStep = step;
    notifyListeners();
  }

  void setMode(String mode) {
    _currentMode = mode;
    notifyListeners();
  }

  void selectCombo(List<String> flowerIds, double seed, int greeneryIdx) {
    _selectedFlowers.clear();
    for (var id in flowerIds) {
      _selectedFlowers[id] = (_selectedFlowers[id] ?? 0) + 1;
    }
    _arrangementSeed = seed;
    _greeneryIndex = greeneryIdx;
    _currentStep = 'arrange';
    _placedFlowers = generateArrangement(getSelectedFlowerList(), _arrangementSeed);
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  // Selection state modifiers
  void toggleFlowerSelection(String flowerId, int delta) {
    // Save to undo stack
    _undoStack.push(Map<String, int>.from(_selectedFlowers));
    _redoStack.clear();

    final currentVal = _selectedFlowers[flowerId] ?? 0;
    final newVal = currentVal + delta;
    if (newVal <= 0) {
      _selectedFlowers.remove(flowerId);
    } else {
      _selectedFlowers[flowerId] = newVal;
    }
    notifyListeners();
  }

  void surpriseMe() {
    _undoStack.push(Map<String, int>.from(_selectedFlowers));
    _redoStack.clear();

    final rand = math.Random();
    final count = rand.nextInt(5) + 6; // 6 to 10 flowers
    _selectedFlowers.clear();
    
    for (int i = 0; i < count; i++) {
      final flower = flowers[rand.nextInt(flowers.length)];
      _selectedFlowers[flower.id] = (_selectedFlowers[flower.id] ?? 0) + 1;
    }

    _arrangementSeed = rand.nextDouble();
    _placedFlowers = generateArrangement(getSelectedFlowerList(), _arrangementSeed);
    _currentStep = 'arrange';
    notifyListeners();
  }

  void resetBuilder() {
    _selectedFlowers.clear();
    _placedFlowers.clear();
    _greeneryIndex = 0;
    _wrappingPaper = 'wrap-classic';
    _ribbonColorIndex = 0;
    _bouquetMessage = '';
    _arrangementSeed = math.Random().nextDouble();
    _currentStep = 'pick';
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.push(Map<String, int>.from(_selectedFlowers));
      _selectedFlowers = _undoStack.pop();
      notifyListeners();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.push(Map<String, int>.from(_selectedFlowers));
      _selectedFlowers = _redoStack.pop();
      notifyListeners();
    }
  }

  // Arrangement state modifiers
  void generateNewArrangement() {
    _arrangementSeed = math.Random().nextDouble();
    _placedFlowers = generateArrangement(getSelectedFlowerList(), _arrangementSeed);
    notifyListeners();
  }

  void setGreeneryIndex(int index) {
    _greeneryIndex = index;
    notifyListeners();
  }

  void setWrappingPaper(String paper) {
    _wrappingPaper = paper;
    notifyListeners();
  }

  void setRibbonColor(int index) {
    _ribbonColorIndex = index;
    notifyListeners();
  }

  void setMessage(String message) {
    _bouquetMessage = message;
    notifyListeners();
  }

  void updatePlacedFlowerPosition(int index, double dx, double dy) {
    if (index >= 0 && index < _placedFlowers.length) {
      _placedFlowers[index].x = dx;
      _placedFlowers[index].y = dy;
      notifyListeners();
    }
  }

  // Profile Auth
  Future<void> createProfile(String name, String avatar) async {
    _profile = UserProfile(
      name: name,
      avatarEmoji: avatar,
      createdAt: DateTime.now(),
    );
    await _prefs?.setString('user_profile', json.encode(_profile!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    _profile = null;
    await _prefs?.remove('user_profile');
    notifyListeners();
  }

  bool get isLoggedIn => true;

  // Counter
  Future<void> incrementBouquetCounter() async {
    _createdBouquetsCount++;
    await _prefs?.setInt('created_bouquets_count', _createdBouquetsCount);
    notifyListeners();
  }

  // Saved Bouquets management
  Future<void> saveBouquetToGarden(String creatorName) async {
    final bouquet = Bouquet(
      id: math.Random().nextInt(999999).toString(),
      flowers: getSelectedFlowerList(),
      greeneryIndex: _greeneryIndex,
      seed: (_arrangementSeed * 100000).floor(),
      creator: creatorName,
      mode: _currentMode,
      message: _bouquetMessage,
      wrappingPaper: _wrappingPaper,
      ribbonColorIndex: _ribbonColorIndex,
      date: DateTime.now(),
    );

    _savedBouquets.insert(0, bouquet);
    final stringList = _savedBouquets.map((b) => json.encode(b.toJson())).toList();
    await _prefs?.setStringList('saved_bouquets', stringList);
    notifyListeners();
  }

  Future<void> deleteSavedBouquet(String id) async {
    _savedBouquets.removeWhere((b) => b.id == id);
    final stringList = _savedBouquets.map((b) => json.encode(b.toJson())).toList();
    await _prefs?.setStringList('saved_bouquets', stringList);
    notifyListeners();
  }

  // Likes
  Future<void> toggleLike(String id) async {
    if (_likedBouquets.contains(id)) {
      _likedBouquets.remove(id);
    } else {
      _likedBouquets.add(id);
    }
    await _prefs?.setStringList('liked_bouquets', _likedBouquets.toList());
    notifyListeners();
  }

  bool isLiked(String id) => _likedBouquets.contains(id);

  // Helper selectors
  List<String> getSelectedFlowerList() {
    final List<String> list = [];
    _selectedFlowers.forEach((id, count) {
      for (int i = 0; i < count; i++) {
        list.add(id);
      }
    });
    return list;
  }

  // Deterministic daily pick rotation matching home.js
  List<Flower> getTodaysPick() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(firstDayOfYear).inDays;
    
    final pick1 = flowers[(dayOfYear * 3) % flowers.length];
    final pick2 = flowers[(dayOfYear * 3 + 1) % flowers.length];
    final pick3 = flowers[(dayOfYear * 3 + 2) % flowers.length];
    
    return [pick1, pick2, pick3];
  }

  // Core golden-ratio layout algorithm matching JS positions
  List<PlacedFlower> generateArrangement(List<String> flowerList, double seed) {
    final rand = seededRandom((seed * 100000).floor());
    final List<PlacedFlower> positions = [];
    const double canvasWidth = 520;
    const double canvasHeight = 580;
    const double centerX = canvasWidth / 2;
    const double centerY = canvasHeight * 0.42;

    for (int i = 0; i < flowerList.length; i++) {
      final flowerId = flowerList[i];
      final double goldenAngle = math.pi * (3 - math.sqrt(5));
      final double angle = i * goldenAngle + rand() * 0.8;
      final double t = i / math.max(flowerList.length - 1, 1);
      final double radius = 25 + t * 120 + rand() * 35;
      final double x = centerX + math.cos(angle) * radius * 0.9 - 60;
      final double y = centerY + math.sin(angle) * radius * 0.7 - 60;
      final double rotation = (rand() - 0.5) * 30;
      final double scale = 0.7 + rand() * 0.4;
      final int zIndex = 3 + (rand() * 12).floor();

      positions.add(PlacedFlower(
        flowerId: flowerId,
        x: math.max(canvasWidth * 0.05, math.min(canvasWidth * 0.75, x)),
        y: math.max(canvasHeight * 0.05, math.min(canvasHeight * 0.62, y)),
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
      ));
    }

    positions.sort((a, b) => a.y.compareTo(b.y));
    return positions;
  }

  double Function() seededRandom(int seed) {
    int s = seed;
    return () {
      s = (s * 16807) % 2147483647;
      return (s - 1) / 2147483646;
    };
  }
}

// Simple Stack Extension for list undo/redo helper
extension StackListExtension<T> on List<T> {
  void push(T val) => add(val);
  T pop() => removeLast();
}
