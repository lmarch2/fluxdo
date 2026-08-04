import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../models/connect_stats.dart';
import '../services/network/discourse_dio.dart';
import 'core_providers.dart';

/// connect.linux.do 统计 Provider
final connectStatsProvider = FutureProvider<ConnectStats?>((ref) async {
  if (!AppConstants.enableLinuxDoServices) return null;

  final user = ref.watch(
    currentUserProvider.select((value) => value.value),
  );
  if (user == null) return null;

  final dio = DiscourseDio.create();
  final response = await dio.get('https://connect.linux.do/');
  if (response.statusCode == 200) {
    return ConnectStats.fromHtml(response.data);
  }
  return null;
});
