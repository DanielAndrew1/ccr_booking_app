import '../core/imports.dart';

class BookingProvider extends ChangeNotifier {
  List<AppBooking> _allBookings = [];
  bool _isLoading = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  List<AppBooking> get allBookings => _allBookings;
  bool get isLoading => _isLoading;

  // This fetches the data from your Supabase 'bookings' table
  Future<void> fetchAllBookings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _supabase
          .from('bookings')
          .select()
          .order('created_at');
      _allBookings = (data as List)
          .map((json) => AppBooking.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint("Fetch Bookings Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Optional: Add a method to clear data on logout
  void clearBookings() {
    _allBookings = [];
    notifyListeners();
  }
}
