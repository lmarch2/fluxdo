import 'dart:io';

import 'package:path/path.dart' as p;

import '_cli_ui.dart';
import '_workspace_cli.dart';

final _cliUi = CliUi();

Future<void> main(List<String> args) async {
  enterWorkspaceRoot();

  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }

  final yes = args.contains('--yes') || args.contains('-y');
  final filteredArgs = args
      .where((arg) => arg != '--yes' && arg != '-y')
      .toList(growable: false);

  if (!Platform.isMacOS) {
    stderr.writeln('iOS 无签名 IPA 只能在 macOS 上打包');
    exit(64);
  }

  final version = await _resolveVersion(filteredArgs);
  if (version.isEmpty) {
    stderr.writeln('无法确定版本号');
    exit(1);
  }

  if (!yes &&
      (await _cliUi.confirm(
            prompt: '确认构建 iOS 无签名 IPA ($version)?',
            defaultValue: true,
          ) !=
          true)) {
    stdout.writeln('==> 已取消');
    return;
  }

  final ipaDir = Directory('build/ios/ipa')..createSync(recursive: true);
  final ipaPath = p.join(ipaDir.path, 'fluxidc-$version-nosign.ipa');

  stdout.writeln('==> 构建 iOS 无签名 IPA ($version)');
  await runOrExit(
    title: '构建 iOS 应用',
    executable: Platform.resolvedExecutable,
    arguments: const ['tool/flutterw.dart', 'build', 'ios', '--release', '--no-codesign'],
  );

  final runnerApp = Directory('build/ios/iphoneos/Runner.app');
  if (!runnerApp.existsSync()) {
    stderr.writeln('缺少构建产物: ${runnerApp.path}');
    exit(1);
  }

  final tempDir = await Directory.systemTemp.createTemp('idcflare_ipa_');
  try {
    final payloadDir = Directory(p.join(tempDir.path, 'Payload'))..createSync(recursive: true);
    await _copyDirectory(runnerApp, Directory(p.join(payloadDir.path, 'Runner.app')));

    final ipaFile = File(ipaPath);
    if (ipaFile.existsSync()) {
      ipaFile.deleteSync();
    }

    await runOrExit(
      title: '打包 IPA',
      executable: 'zip',
      arguments: ['-qr', ipaFile.absolute.path, 'Payload'],
      workingDirectory: tempDir.path,
    );
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }

  stdout.writeln('==> IPA 已输出: $ipaPath');
}

Future<String> _resolveVersion(List<String> args) async {
  if (args.isNotEmpty) {
    return args.first.trim();
  }

  final pubspecVersion = _readVersionFromPubspec();
  if (!_cliUi.canPrompt) {
    return pubspecVersion;
  }

  final selected = await _cliUi.input(
    prompt: '输入 iOS 无签名 IPA 版本号',
    defaultValue: pubspecVersion,
  );
  return selected?.trim() ?? '';
}

String _readVersionFromPubspec() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    return '';
  }
  final match = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(
    pubspecFile.readAsStringSync(),
  );
  return match?.group(1)?.split('+').first.trim() ?? '';
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  destination.createSync(recursive: true);
  await for (final entity in source.list(recursive: false, followLinks: false)) {
    final targetPath = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      File(targetPath).parent.createSync(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

const _usage = '''
用法:
  dart tool/build_ipa_nosign.dart [版本号] [-y|--yes]
''';
