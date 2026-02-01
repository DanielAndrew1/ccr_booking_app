import '../core/imports.dart';

class NavbarProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isEditMode = false; // Tracks if we are editing

  int get selectedIndex => _selectedIndex;
  bool get isEditMode => _isEditMode;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // Call this when clicking the edit button in the dialog
  void setEditMode(bool value) {
    _isEditMode = value;
    notifyListeners();
  }
}
