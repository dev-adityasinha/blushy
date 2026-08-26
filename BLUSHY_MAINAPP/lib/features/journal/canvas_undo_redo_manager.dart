import 'journal_screen.dart';

class CanvasSnapshot {
  final List<ScrapbookItem> items;
  CanvasSnapshot(this.items);
}

class CanvasUndoRedoManager {
  final List<List<ScrapbookItem>> _undoStack = [];
  final List<List<ScrapbookItem>> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void recordState(List<ScrapbookItem> currentItems) {
    // Save a deep copy of items
    final snapshot = currentItems.map((item) => item.copyWith()).toList();
    _undoStack.add(snapshot);
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0); // Max 30 undo steps
    }
    _redoStack.clear();
  }

  List<ScrapbookItem>? undo(List<ScrapbookItem> currentItems) {
    if (_undoStack.isEmpty) return null;
    final currentState = currentItems.map((item) => item.copyWith()).toList();
    _redoStack.add(currentState);

    final previousState = _undoStack.removeLast();
    return previousState.map((item) => item.copyWith()).toList();
  }

  List<ScrapbookItem>? redo(List<ScrapbookItem> currentItems) {
    if (_redoStack.isEmpty) return null;
    final currentState = currentItems.map((item) => item.copyWith()).toList();
    _undoStack.add(currentState);

    final nextState = _redoStack.removeLast();
    return nextState.map((item) => item.copyWith()).toList();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
