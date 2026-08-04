import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/cdk_user_info.dart';
import '../services/cdk_oauth_service.dart';
import '../services/network/exceptions/oauth_exception.dart';
import 'core_providers.dart';

final cdkUserInfoProvider = AsyncNotifierProvider<CdkUserInfoNotifier, CdkUserInfo?>(() {
  return CdkUserInfoNotifier();
});

class CdkUserInfoNotifier extends AsyncNotifier<CdkUserInfo?> {
  static const String _cacheKey = 'cdk_user_info';
  static const String _cdkEnabledKey = 'cdk_enabled';
  static const String _cacheUserKey = 'cdk_user_info_username';

  // 防止 build() 与 refresh() 在 notifier 首次创建时并发触发同接口，
  // 复用同一个 in-flight future
  Future<CdkUserInfo?>? _inFlightFetch;

  @override
  Future<CdkUserInfo?> build() async {
    if (!AppConstants.enableLinuxDoServices) return null;

    final prefs = await SharedPreferences.getInstance();
    // 只 watch username:currentUser 对象其他字段刷新时不应触发 CDK 接口的重新请求
    final currentUsername = ref.watch(
      currentUserProvider.select((value) => value.value?.username),
    );
    final username =
        currentUsername ??
        (await ref.watch(currentUserProvider.future))?.username;
    if (username == null) {
      await _clearCache(prefs);
      return null;
    }
    final enabled = prefs.getBool(_cdkEnabledKey) ?? false;

    if (!enabled) return null;

    // 先读取缓存，用于网络失败时兜底
    CdkUserInfo? cachedInfo;
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final cachedUser = prefs.getString(_cacheUserKey);
        if (cachedUser != null && cachedUser != username) {
          await _clearCache(prefs);
        } else {
          cachedInfo = CdkUserInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      } catch (_) {
        // 缓存损坏，忽略
      }
    }

    try {
      return await _fetchUserInfo();
    } on OAuthExpiredException catch (_) {
      // 授权过期：清除缓存，让错误状态透传到 UI
      await _clearCache(prefs);
      rethrow;
    } catch (e) {
      if (cachedInfo != null) return cachedInfo;
      rethrow;
    }
  }

  Future<CdkUserInfo?> _fetchUserInfo() {
    return _inFlightFetch ??=
        _doFetchUserInfo().whenComplete(() => _inFlightFetch = null);
  }

  Future<CdkUserInfo?> _doFetchUserInfo() async {
    if (!AppConstants.enableLinuxDoServices) return null;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_cdkEnabledKey) ?? false;

    if (!enabled) return null;

    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return null;

    final service = CdkOAuthService();
    final userInfo = await service.getUserInfo();

    if (userInfo != null) {
      await prefs.setString(_cacheKey, jsonEncode(userInfo.toJson()));
      await prefs.setString(_cacheUserKey, userInfo.username);
    }

    return userInfo;
  }

  Future<void> refresh() async {
    final previousData = state.value;
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<CdkUserInfo?>().copyWithPrevious(state);
    try {
      final result = await _fetchUserInfo();
      state = AsyncValue.data(result);
    } catch (e, st) {
      if (e is OAuthExpiredException) {
        // 登录态过期：清除缓存并立即反映到 UI
        final prefs = await SharedPreferences.getInstance();
        await _clearCache(prefs);
        state = AsyncValue.error(e, st);
      } else if (previousData != null) {
        // 网络错误等：保留旧数据
        state = AsyncValue.data(previousData);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearCache(prefs);
    state = const AsyncValue.data(null);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cdkEnabledKey, false);
    await _clearCache(prefs);
    state = const AsyncValue.data(null);
  }

  Future<void> _clearCache(SharedPreferences prefs) async {
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheUserKey);
  }
}
