import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectCommercialService {
  ProjectCommercialService(this._supabase);

  final SupabaseClient _supabase;
  static const _contractsBucket = 'project-contracts';

  Future<String> uploadContract({
    required String projectId,
    required File imageFile,
  }) async {
    final extension = imageFile.path.split('.').last.toLowerCase();
    final path = '$projectId/contract.$extension';
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
    await _supabase.storage
        .from(_contractsBucket)
        .upload(
          path,
          imageFile,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return path;
  }

  Future<String?> createContractUrl(String? contractPath) async {
    if (contractPath == null || contractPath.isEmpty) return null;
    return _supabase.storage
        .from(_contractsBucket)
        .createSignedUrl(contractPath, 60 * 60);
  }
}
