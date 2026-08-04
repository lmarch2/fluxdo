# IDCFlare

<p align="center">
  <img src="assets/images/idcflare_mark.png" width="128" alt="IDC Flare mark">
</p>

IDCFlare 是面向 [IDC Flare](https://idcflare.com/) 社区的非官方跨平台客户端，基于 [FluxDO](https://github.com/Lingyan000/fluxdo) v0.2.25 适配。项目保留 FluxDO 的 Flutter、Discourse、WebView 登录与 Cookie 同步能力，并将站点、品牌、深链和平台包名切换到 IDC Flare。

本项目与 IDC Flare 官方及 FluxDO 上游作者均无隶属关系。IDC Flare 名称与图形标志归其权利人所有。

## 当前状态

- 站点地址：`https://idcflare.com`
- 自定义协议：`idcflare://`，同时保留 Discourse 标准 `discourse://auth_redirect`
- 平台标识：`com.fdcflare.client`
- 支持平台：Android、iOS、macOS、Windows、Linux
- Web：暂不支持；原生动态图、DoH 代理、AVIF 与 QuickJS 等功能依赖 `dart:ffi`
- 应用内自动更新：默认关闭，配置独立发布仓库后再启用
- Linux.DO Credit、CDK、Connect 与元宇宙服务：关闭
- 崩溃上报：默认关闭，配置独立后端后再启用

## 功能

- 浏览分类、话题、帖子、用户资料与通知
- 发帖、回复、编辑、搜索、书签与浏览历史
- Markdown 编辑、预览、图片与音视频处理
- WebView 登录兜底，兼容 Cloudflare 验证与站点 Cookie
- 深色模式、动态取色、响应式移动端与桌面端布局
- Rust DoH 代理、内容缓存与 Discourse MessageBus 通知

## 开发环境

- Flutter `3.44.0`（见 `.fvmrc`）
- Dart SDK `^3.10.4`
- Rust stable（编译 `core/doh_proxy`）
- 对应平台工具链：Android Studio、Xcode、Visual Studio 或 Linux GTK 开发包

初始化并运行：

```bash
dart run melos bootstrap
dart run tool/project_prep.dart app
dart run tool/flutterw.dart run -d macos
```

也可以安装 `just` 后使用统一入口：

```bash
just sync
just run -- -d macos
just analyze
just test
```

Android 构建建议显式关闭 Play Services Cronet：

```bash
dart run tool/flutterw.dart build apk --release \
  --dart-define=cronetHttpNoPlay=true
```

更完整的开发和打包说明见：

- [开发环境与日常命令](docs/development.md)
- [Flatpak 打包](docs/flatpak.md)
- [发布流程](docs/release.md)

## 站点适配

IDC Flare 相关常量位于 `lib/constants.dart`，站点安全域名配置位于 `lib/config/sites/idcflare.dart`。需要接入独立发布仓库或崩溃上报服务时，应先替换对应后端配置，再开启功能开关，避免读取 FluxDO 上游发布或数据服务。

## 上游与协议

本项目基于 FluxDO 修改，具体基线、子模块版本和保留项见 [UPSTREAM.md](UPSTREAM.md)。源代码继续使用 [GNU GPL v3](LICENSE)；分发修改版本时须遵守 GPL-3.0 的源码与许可证要求，并保留上游署名。
