import '../core/imports.dart';

class BookingProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> get allBookings => _allBookings;

  Map<String, dynamic>? _editingBooking;
  Map<String, dynamic>? get editingBooking => _editingBooking;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setEditingBooking(Map<String, dynamic>? booking) {
    _editingBooking = booking;
    notifyListeners();
  }

  void clearEditingBooking() {
    _editingBooking = null;
    notifyListeners();
  }

  void clearBookings() {
    _allBookings = [];
    _editingBooking = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllBookings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await supabase
          .from('bookings')
          .select()
          .order('pickup_datetime', ascending: false);

      _allBookings = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
