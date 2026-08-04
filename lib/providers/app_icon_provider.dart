import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_provider.dart';

/// 应用图标风格（用户只选择风格，深浅色由系统自适应处理）
enum AppIconStyle {
  /// 经典 FluxIDC 图标
  classic,

  /// 现代图标
  modern,
}

/// 应用图标状态
class AppIconState {
  final AppIconStyle currentStyle;
  final bool isChanging;

  const AppIconState({
    this.currentStyle = AppIconStyle.classic,
    this.isChanging = false,
  });

  AppIconState copyWith({
    AppIconStyle? currentStyle,
    bool? isChanging,
  }) {
    return AppIconState(
      currentStyle: currentStyle ?? this.currentStyle,
      isChanging: isChanging ?? this.isChanging,
    );
  }
}

/// 应用图标管理
class AppIconNotifier extends StateNotifier<AppIconState> {
  static const String _prefKey = 'pref_app_icon';
  static const _platformChannel =
      MethodChannel('com.fdcflare.client/app_icon');
  final SharedPreferences _prefs;

  AppIconNotifier(this._prefs) : super(const AppIconState()) {
    _init();
  }

  AppIconStyle _styleFromSavedValue(String? saved) {
    switch (saved) {
      case 'modern':
      case 'modern_light':
      case 'ModernIcon':
        return AppIconStyle.modern;
      default:
        return AppIconStyle.classic;
    }
  }

  AppIconStyle _styleFromIconName(String? iconName) {
    switch (iconName) {
      case 'ModernIcon':
      case 'modern':
      case 'modern_light':
        return AppIconStyle.modern;
      default:
        return AppIconStyle.classic;
    }
  }

  String _styleToPrefValue(AppIconStyle style) {
    return style == AppIconStyle.modern ? 'modern' : 'classic';
  }

  Future<void> _init() async {
    var style = _styleFromSavedValue(_prefs.getString(_prefKey));

    if (!kIsWeb && Platform.isIOS) {
      try {
        if (await _supportsAlternateIcons()) {
          final currentIconName = await _getCurrentIconName();
          style = _styleFromIconName(currentIconName);
          final prefValue = _styleToPrefValue(style);
          if (_prefs.getString(_prefKey) != prefValue) {
            await _prefs.setString(_prefKey, prefValue);
          }
        }
      } catch (e) {
        debugPrint('读取当前应用图标失败: $e');
      }
    }

    state = state.copyWith(currentStyle: style);
  }

  /// 根据风格获取平台图标名（深浅色由系统自适应处理）
  String? _getIconName(AppIconStyle style) {
    switch (style) {
      case AppIconStyle.classic:
        return null;
      case AppIconStyle.modern:
        return 'ModernIcon';
    }
  }

  /// 调用平台 API 切换图标
  Future<String?> _setPlatformIcon(String? iconName) async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      await _platformChannel
          .invokeMethod('setAlternateIcon', {'iconName': iconName});
      return iconName;
    } else if (Platform.isIOS) {
      return await _platformChannel.invokeMethod<String>('setAlternateIcon', {
        'iconName': iconName,
      });
    }
    return iconName;
  }

  Future<bool> _supportsAlternateIcons() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      return (await _platformChannel.invokeMethod<bool>('supportsAlternateIcons')) ??
          false;
    }
    return true;
  }

  Future<String?> _getCurrentIconName() async {
    if (kIsWeb) return null;
    if (Platform.isIOS) {
      return await _platformChannel.invokeMethod<String>('getAlternateIconName');
    }
    return _getIconName(state.currentStyle);
  }

  Future<bool> _isPlatformIconApplied(AppIconStyle style) async {
    if (kIsWeb) return true;
    if (Platform.isIOS) {
      try {
        if (!await _supportsAlternateIcons()) {
          return style == AppIconStyle.classic;
        }
        return await _getCurrentIconName() == _getIconName(style);
      } catch (e) {
        debugPrint('校验当前应用图标失败: $e');
        return false;
      }
    }
    return style == state.currentStyle;
  }

  void _logPlatformIconException(PlatformException error) {
    debugPrint(
      '切换应用图标失败: '
      'code=${error.code}, '
      'message=${error.message}, '
      'details=${error.details}',
    );
  }

  /// 切换应用图标风格
  Future<bool> setIconStyle(AppIconStyle style) async {
    if (state.isChanging) return true;
    if (style == state.currentStyle && await _isPlatformIconApplied(style)) {
      return true;
    }

    state = state.copyWith(isChanging: true);

    try {
      final iconName = _getIconName(style);
      await _setPlatformIcon(iconName);

      await _prefs.setString(_prefKey, _styleToPrefValue(style));

      state = state.copyWith(
        currentStyle: style,
        isChanging: false,
      );
      return true;
    } on PlatformException catch (e) {
      _logPlatformIconException(e);

      state = state.copyWith(isChanging: false);
      return false;
    } catch (e) {
      debugPrint('切换应用图标失败: $e');
      state = state.copyWith(isChanging: false);
      return false;
    }
  }
}

/// 应用图标 Provider
final appIconProvider =
    StateNotifierProvider<AppIconNotifier, AppIconState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppIconNotifier(prefs);
});
