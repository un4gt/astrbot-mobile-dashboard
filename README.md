# AstrBot Mobile Dashboard

AstrBot 的移动端伴侣应用：在手机上管理你的 AstrBot 服务器——仪表盘、配置编辑、
提供商/平台/插件管理、人设、会话、知识库、实时控制台、WebChat 测试、诊断，
支持多服务器 Profile、应用内自更新、自定义壁纸与本地调试模式。

基于 v4.7.1 服务端 API 开发（见 `refrence/AstrBot`，参考仓库不入库）。

## 功能

- **多服务器 Profile**：保存多台服务器连接，各自独立的登录态与配置，首页一键切换
- **仪表盘**：消息量趋势图、平台消息分布、内存/CPU/运行时长
- **配置**：分组 Tab + 可展开分节，schema 驱动表单（与 Web 端两个 Vue 组件行为对齐）
- **提供商 / 平台 / 插件**：模板选择、实例编辑、插件市场、插件 Logo、二级配置菜单
- **WebChat（测试）**：SSE 流式对话、图片上传、思考过程展示
- **控制台**：实时日志流（级别过滤、自动滚动、断线重连）
- **自更新**：启动自动检查 + 设置页手动检查，应用内下载安装 GitHub Release APK
- **本地调试**：不连服务器，用内置 mock 数据浏览全部页面
- **外观**：主题/语言、应用内壁纸（图片/GIF + 模糊度）

## 环境要求

- Flutter 3.44+（Dart SDK ^3.12.2）
- Java 17（Android Gradle 构建）
- Android SDK（compileSdk 36）

## 开发

```bash
flutter pub get        # 安装依赖
flutter analyze        # 静态检查
flutter test           # 运行单元/组件测试
flutter run            # 连接设备调试运行
```

### 本地打包

```bash
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/app-release.apk`，使用固定 release 密钥签名
（见下方签名说明），可直接覆盖安装到已装旧版本的设备上。

本地打包**不需要升版本号**（用于真机自测）；正式发版流程见下。

### 正式发版

1. 升 `pubspec.yaml` 的 `version`（语义化版本 + build 号，如 `1.4.0+6`）
2. 提交并打 tag：

```bash
git add -A && git commit -m "chore: bump version to x.y.z+n"
git tag -a vx.y.z -m "vx.y.z"
git push origin main --tags
```

3. 推送 `v*` tag 自动触发 [release.yml](.github/workflows/release.yml)：
   CI 跑 analyze/test、签名打包、创建 GitHub Release 并附上
   `astrbot-mobile-x.y.z.apk`
4. 已装旧版的设备启动时会收到新版本提示，应用内完成升级

### 签名

Release 签名使用项目内的固定密钥（`android/` 下，已被 gitignore，不入库）：

- `astrbot-mobile-release.keystore` — 密钥库
- `key.properties` — 密钥口令等配置

`flutter build apk --release` 自动读取它们签名。**换机器打包时必须带上这两个文件**，
否则签名不一致会导致无法覆盖安装。CI 通过仓库 Secrets 注入同一份密钥
（`KEYSTORE_BASE64` 等 4 个，配置方法见 release.yml 顶部注释）。

### 其他脚本

```bash
python scripts/gen_launcher_icon.py   # 从 assets/icon.png 重新生成全套启动图标
```

## 项目结构

```
lib/
  app.dart                # MaterialApp 路由/主题/启动检查
  core/                   # api 客户端、i18n、主题、路由、存储、工具
  shared/                 # 全局 providers 与通用组件
  features/               # 按功能域划分：dashboard/config/provider/platform/
                          # plugin/chat/console/persona/kb/mcp/session/
                          # conversation/auth/setup/settings/update/wallpaper/...
test/                     # 单元与组件测试
assets/i18n/              # zh-CN / en-US 文案
android/                  # Gradle 工程与签名配置
```

## 服务端兼容性

按 AstrBot **v4.7.1** 的 API 逆向适配（对话、配置元数据、abconf 等接口结构均以该版本
为准）。patch 版本（4.7.x）通常兼容；大版本升级服务端后需同步核对移动端字段解析。
