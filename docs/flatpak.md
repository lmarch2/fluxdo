# Flatpak 打包方案

当前 Linux 发布链路改为“两层 CI”：

- `flatpak-wpe-layer` 单独构建并发布预编译的 WPE 依赖层。
- 主 `Build and Release` 先确保依赖层存在，再构建 Fluxdo 自己。

## 当前设计

CI 分成三部分：

0. `flatpak-wpe-layer`
   - 使用 `flatpak/com.fdcflare.client.wpe-layer.yml` 单独构建：
     - `unifdef`
     - `woff2`
     - `libwpe`
     - `wpewebkit`
   - 把 Flatpak build root 下的 `files/` 打成 `idcflare-flatpak-wpe-layer-gnome48-x86_64.tar.zst`。
   - 作为 workflow artifact 上传，并发布到 `flatpak-wpe-layer-<version>` 这个 prerelease tag。
   - 版本号由 `flatpak/wpe-layer.version` 控制，只有 WPE 依赖变化时才需要 bump。

1. `flatpak_prepare_sources`
   - 用固定版本 Flutter 下载 Linux desktop artifacts。
   - 用仓库内 `.pub-cache` 执行 `flutter pub get`，把 Dart/pub 依赖固化到源码树里。
   - 对 Linux 插件应用补丁：
     - `flutter_secure_storage_linux` 的 `json.hpp` 字面量操作符兼容修复。
     - `flutter_inappwebview_linux` 通过仓库内 vendored `nlohmann_json` 走离线 CMake 配置。
   - 对 staged Flutter SDK 应用离线补丁，把 `bin/flutter` 改成直接走 `flutter_tools.snapshot`，避免 Linux desktop 内层 `tool_backend.dart -> bin/flutter assemble` 再次触发联网逻辑。
   - 刷新 staged `.pub-cache` 中的 advisory cache 时间戳，避免 Flatpak sandbox 内部的隐藏 pub 校验因为 advisory 刷新而访问 `pub.dev`。
   - 保留 `.flutter-plugins-dependencies`，在 Flatpak 容器内根据它重建 Linux `.plugin_symlinks`，避免 prepare 阶段宿主机的绝对路径在容器里失效。
   - 对 Linux 需要的 Rust 工程执行 `cargo vendor`，生成离线 `cargo-vendor` 和 `.cargo/config.toml`。
   - 把项目源码、Flutter SDK、`.pub-cache`、Rust vendor 一起打成内部 artifact。

2. `flatpak_package`
   - 解压上一步的源码树 artifact 到 `flatpak/stage/source-tree`。
   - 依赖 `ensure_flatpak_wpe_layer`：
     - 如果 release 里已经有对应版本的 WPE 层，就直接下载并作为当前 run 的 artifact 透传。
     - 如果 release 里还没有，就在当前 run 内现构建一次、发布 prerelease 资产，再继续主构建。
   - 从当前 run 的 artifact 解压 `WPE layer` 到 `flatpak/stage/wpe-layer/`。
   - 在 `ghcr.io/flathub-infra/flatpak-github-actions:gnome-48` 特权容器中运行 `flatpak-builder`。
   - 通过 `flatpak-builder` 在 `org.gnome.Sdk` 中直接运行：
     - `cargo build`
     - 写入 `linux/flutter/ephemeral/generated_config.cmake`
     - `cmake -G Ninja ...`
     - `ninja -C build/linux/x64/release install`
   - 这里不再调用外层 `flutter build linux`，因为它在当前 Flutter 版本里仍会触发一条隐藏的 `pub get` 校验链，对 Flatpak sandbox 来说不可靠。
   - `flutter_inappwebview_linux` 继续使用真实 WPE 后端，但主应用 CI 不再自己源码编 `wpewebkit`。
   - Linux bundle 的 Dart/Flutter 资源仍然通过 CMake 自定义命令里的 `tool_backend.sh -> flutter assemble` 生成；前面已经对 staged SDK 的 `bin/flutter` 做了离线补丁，避免这条链回退到原始 wrapper。
   - `flutter assemble` 会运行 Dart build hooks；`sqlite3` 包（经 `sqflite_common_ffi` 引入）的 hook 默认在构建期从 GitHub 下载预编译库，在离线沙箱内必然失败。根级 `pubspec.yaml` 通过 `hooks.user_defines.sqlite3` 把它切换为编译仓库内 vendored 的 `third_party/sqlite3/sqlite3.c`（amalgamation），保持全程离线，详见 `third_party/sqlite3/README.md`。
   - 最终把生成的 Linux bundle 安装到 `/app/idcflare`，输出 `.flatpak`。

## 这样做解决了什么

- 不再把 Arch 构建产物塞进 `org.gnome.Platform`，避免 `libinput`、`icu`、WPE 链条出现 ABI 漂移。
- Flatpak 构建阶段不依赖公网拉 Dart、Cargo、CMake 第三方源，CI 结果可复现。
- Linux WebView 继续走真实 WPE 实现，Flatpak 不再依赖宿主机是否恰好装好了 WPE 开发包。
- 主应用 Flatpak CI 不再每次源码编整个 `wpewebkit`，首次构建重依赖的成本被挪到了独立工作流。
- 即使第一次缺少预编译依赖层，主 workflow 也会自动补建，不需要先手动失败一次。

## 关键文件

- `.github/workflows/build.yaml`
- `.github/workflows/flatpak-wpe-layer.yaml`
- `flatpak/com.fdcflare.client.yml`
- `flatpak/com.fdcflare.client.wpe-layer.yml`
- `flatpak/wpe-layer.version`
- `linux/CMakeLists.txt`
- `scripts/ci/flatpak/prepare_source_tree.sh`
- `scripts/ci/flatpak/patch_staged_flutter_sdk.sh`
- `scripts/ci/flatpak/refresh_pub_advisories_cache.py`
- `scripts/ci/flatpak/rebuild_linux_plugin_symlinks.py`
- `scripts/ci/linux/write_generated_config.py`
- `scripts/ci/flatpak/build_app.sh`
- `scripts/ci/flatpak/package_wpe_layer.sh`
- `scripts/ci/linux/list_rust_manifests.py`
- `scripts/ci/linux/patch_plugins.sh`
- `scripts/ci/flatpak/run_local_package.sh`

## 本地调试

前置条件：

- 主机有 Flutter、Rust、Docker

推荐直接跑仓库内脚本，这条路径比 `act` 更接近实际的 `flatpak_package` job：

```bash
bash scripts/ci/flatpak/run_local_package.sh
```

如果只想复用已经准备好的 `.artifacts/flatpak/idcflare-flatpak-source-tree.tar.gz`，可以跳过 prepare：

```bash
SKIP_PREPARE=1 bash scripts/ci/flatpak/run_local_package.sh
```

如果要手动拆开跑，命令如下：

- 主机需安装 `flatpak-builder`
- 已安装 `org.gnome.Platform//48`、`org.gnome.Sdk//48`
- 已安装 `org.freedesktop.Sdk.Extension.rust-stable`

```bash
export PUB_CACHE="$PWD/.pub-cache"
bash scripts/ci/flatpak/prepare_source_tree.sh
rm -rf flatpak/stage/source-tree
mkdir -p flatpak/stage/source-tree
tar -xzf .artifacts/flatpak/idcflare-flatpak-source-tree.tar.gz -C flatpak/stage/source-tree
flatpak-builder --user --install-deps-from=flathub --force-clean --repo=repo flatpak_app flatpak/com.fdcflare.client.yml
flatpak build-bundle repo idcflare-linux-x86_64.flatpak com.fdcflare.client stable
```

如果只想验证 SDK 里有没有对应开发包，可以按 Flatpak 官方文档提供的方式执行：

```bash
flatpak run --command=pkg-config org.gnome.Sdk//48 --modversion wpe-webkit-2.0
flatpak run --command=pkg-config org.gnome.Sdk//48 --modversion wpe-1.0
flatpak run --command=pkg-config org.gnome.Sdk//48 --modversion libsecret-1
```

如果要手动更新预编译 WPE 层：

1. 修改 `flatpak/wpe-layer.version`
2. 触发 `Build Flatpak WPE Layer`
3. 等它发布新的 `flatpak-wpe-layer-<version>` prerelease 资产
4. 再跑主 `Build and Release`

如果要本地复用一个已经下载好的 WPE 层归档，可以这样跑：

```bash
LOCAL_WPE_LAYER_ARCHIVE=/path/to/idcflare-flatpak-wpe-layer-gnome48-x86_64.tar.zst \
SKIP_PREPARE=1 \
bash scripts/ci/flatpak/run_local_package.sh
```

如果要验证预编译依赖层已经被主 manifest 正确安装到 app build root，可以在 Flatpak 构建结束后检查：

```bash
flatpak-builder --run flatpak_app flatpak/com.fdcflare.client.yml sh -lc \
  'pkg-config --modversion wpe-webkit-2.0 && pkg-config --modversion wpe-platform-2.0 && pkg-config --modversion wpe-platform-headless-2.0'
```
