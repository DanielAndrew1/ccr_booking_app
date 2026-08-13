import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectFinanceService {
  ProjectFinanceService(this._supabase);

  final SupabaseClient _supabase;

  Future<void> syncProjectFinance(String projectId) => _supabase.rpc(
    'sync_project_finance',
    params: {'target_booking_id': projectId},
  );

  Future<Map<String, dynamic>> dashboard() async {
    final rows = await _supabase.from('finance_dashboard').select();
    return rows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> schedules(String projectId) async {
    final rows = await _supabase
        .from('payment_schedules')
        .select()
        .eq('booking_id', projectId)
        .order('due_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> recordPayment({
    required String scheduleId,
    required double amount,
    required String method,
  }) => _supabase.rpc(
    'record_project_payment',
    params: {
      'target_schedule_id': scheduleId,
      'payment_amount': amount,
      'payment_method': method,
    },
  );
}
