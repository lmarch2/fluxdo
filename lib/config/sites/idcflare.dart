import '../site_customization.dart';

/// IDC Flare 站点自定义配置。
final idcflareCustomization = SiteCustomization(
  linkSecurityConfig: _idcflareLinkSecurityConfig,
);

const _idcflareLinkSecurityConfig = LinkSecurityConfig(
  enableExitConfirmation: true,
  internalDomains: [
    '*.idcflare.com',
    'localhost',
    '*.local',
    '^127(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}',
    '^10(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}',
    '^192\\.168(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
    '^172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
  ],
  trustedDomains: [
    '*.linux.do',
    '*.linuxdo.org',
    '*.uasm.net',
    '*.wegram.org',
    '*.zhile.io',
    '*.oaifree.com',
    '*.oaipro.com',
    't.me/idcflare',
  ],
  riskyDomains: [
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'ow.ly',
    'tiny.cc',
    'is.gd',
    'v.gd',
    'link.zip',
    '*.short.link',
  ],
  dangerousDomains: ['**aff='],
);
