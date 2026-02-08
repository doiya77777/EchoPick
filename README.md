# EchoPick 拾响

> 语音笔记，放口袋里就行。

**原始文本是资产（Echo），离散数据是索引（Pick）。**

## 核心功能

- **无感录音** — 一键开始，后台静默录制，每 5 分钟自动分段
- **流式转录** — 火山引擎 Seed ASR 实时语音识别
- **源数据优先** — 音频文件 + 完整文本随时回放、复制
- **AI 辅助分析** — Seed LLM 自动提取话题、数据、待办（折叠展示，不喧宾夺主）
- **溯源交互** — 点击 Pick 卡片，原文高亮并滚动定位

## 隐私

- 纯本地存储（SwiftData）+ iCloud 同步
- API Key 存 Keychain
- Face ID 应用锁
- 无自建后端

## 技术栈

| 层级 | 技术 |
|------|------|
| UI | SwiftUI · MVVM · iOS 17+ |
| 持久化 | SwiftData + iCloud |
| 语音识别 | 火山引擎 Seed ASR 2.0（WebSocket 流式） |
| 智能提取 | 火山引擎 Seed LLM（JSON Mode） |
| 安全 | Keychain + LocalAuthentication |
| 项目管理 | XcodeGen |

## 快速开始

```bash
# 生成 Xcode 项目
xcodegen generate

# 构建（真机）
xcodebuild -project EchoPick.xcodeproj -scheme EchoPick \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -configuration Release -allowProvisioningUpdates \
  CONFIGURATION_BUILD_DIR=build-device build

# 安装
xcrun devicectl device install app --device <DEVICE_ID> build-device/EchoPick.app
```

## 文档

- **[DEVELOPMENT.md](DEVELOPMENT.md)** — 架构设计、功能开发、UI/UX 规范、测试策略、真机部署

## License

MIT © 2026 doiya
