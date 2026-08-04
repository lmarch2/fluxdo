# IDCFlare

<p align="center">
  <img src="assets/images/idcflare_mark.png" width="128" alt="IDCFlare 图标">
</p>

<p align="center">
  面向 <a href="https://idcflare.com/">IDC Flare</a> 社区的非官方跨平台客户端
</p>

<p align="center">
  <a href="https://github.com/lmarch2/fluxdo/releases"><img src="https://img.shields.io/badge/status-testing-orange" alt="当前状态：测试中"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/lmarch2/fluxdo" alt="License"></a>
  <img src="https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter" alt="Flutter 3.44.0">
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-555" alt="支持平台">
</p>

<p align="center">
  <a href="https://github.com/lmarch2/fluxdo/releases">下载</a> ·
  <a href="docs/development.md">开发文档</a> ·
  <a href="https://github.com/lmarch2/fluxdo/issues">问题反馈</a> ·
  <a href="UPSTREAM.md">上游说明</a>
</p>

IDCFlare 基于 [FluxDO](https://github.com/Lingyan000/fluxdo) v0.2.25 适配，保留其 Flutter、Discourse、WebView 登录和 Cookie 同步能力，并将站点、品牌、深链及平台包名切换到 IDC Flare。

> [!IMPORTANT]
> 本项目是社区维护的非官方客户端，与 IDC Flare 官方及 FluxDO 上游作者均无隶属关系。使用前请自行判断风险并妥善保管账号数据。IDC Flare 名称与图形标志归其权利人所有。

## 下载与安装

已发布的安装包会出现在 [GitHub Releases](https://github.com/lmarch2/fluxdo/releases)。项目目前处于适配测试阶段，尚未发布正式 Release；不要从不明来源下载重新打包的 APK。

Android 安装包按 ABI 分开构建：

| 文件名后缀 | 适用设备 |
| --- | --- |
| `arm64-v8a` | 绝大多数近年的 Android 手机和平板 |
| `armeabi-v7a` | 较老的 32 位 Android 设备 |
| `x86_64` | Android 模拟器及少数 x86 设备 |

下载对应 APK 后，可直接在系统文件管理器中打开安装，或使用 ADB：

```bash
adb install -r idcflare-arm64-v8a.apk
```

未配置 Android 签名 secrets 时，CI 和本地 release 构建会回退到调试签名。不同签名的 APK 不能直接覆盖安装；遇到签名冲突时，应先备份应用数据，再卸载旧版本。

## 当前状态

- 目标站点：`https://idcflare.com`
- Android 包名：`com.fdcflare.client`
- 自定义协议：`idcflare://`，同时保留 Discourse 标准 `discourse://auth_redirect`
- Android `arm64-v8a` release APK 已完成构建、包名、ABI、原生库和 v2 签名验证
- iOS、macOS、Windows 和 Linux 工程已完成品牌与标识适配，仍需对应平台的完整构建验证
- Web 暂不支持；动态图、DoH 代理、AVIF 和 QuickJS 等功能依赖 `dart:ffi`
- 应用内自动更新和崩溃上报默认关闭，配置独立后端后方可启用
- Linux.DO 专属的 Credit、CDK、Connect 和元宇宙服务已关闭

## 主要功能

- 浏览分类、话题、帖子、用户资料和通知
- 发帖、回复、编辑、搜索、书签及浏览历史
- Markdown 编辑与预览、图片和音视频处理
- WebView 登录兜底，兼容 Cloudflare 验证和站点 Cookie
- 深色模式、动态取色及移动端与桌面端响应式布局
- Rust DoH 代理、内容缓存和 Discourse MessageBus 通知

## 从源码构建

需要 Flutter `3.44.0`、Dart SDK `^3.10.4`、Rust stable，以及目标平台对应的原生工具链。克隆时需要同时拉取子模块：

```bash
git clone --recurse-submodules https://github.com/lmarch2/fluxdo.git
cd fluxdo
dart run melos bootstrap
dart run tool/project_prep.dart app
```

运行桌面端：

```bash
dart run tool/flutterw.dart run -d macos
```

构建 Android arm64 APK：

```bash
dart run tool/flutterw.dart build apk --release \
  --target-platform android-arm64 \
  --dart-define=cronetHttpNoPlay=true
```

也可以安装 [`just`](https://github.com/casey/just) 后使用统一入口：

```bash
just sync
just run -- -d macos
just analyze
just test
```

更多说明：

- [开发环境与日常命令](docs/development.md)
- [Flatpak 打包](docs/flatpak.md)
- [发布流程](docs/release.md)

## 站点适配

IDC Flare 常量位于 `lib/constants.dart`，站点能力与安全域名配置位于 `lib/config/sites/idcflare.dart`。接入独立发布仓库或崩溃上报服务前，应先替换相应后端配置，再开启功能开关，避免读取 FluxDO 上游的发布或数据服务。

## 上游与许可证

本项目基于 FluxDO 修改，具体基线、子模块版本和保留项见 [UPSTREAM.md](UPSTREAM.md)。源代码继续使用 [GNU GPL v3](LICENSE)；分发修改版本时须遵守 GPL-3.0 的源码和许可证要求，并保留上游署名。
