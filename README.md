# 🧠 VibeMemo

> 随时随地记录灵感，捕捉与朋友的对话。AI 驱动，隐私优先。

<p align="center">
  <img src="docs/icon.png" width="128" alt="VibeMemo Icon" />
</p>

## ✨ 特点

- 📝 **快速笔记** — 随手记录想法，支持标签和情感标注
- 🎙️ **语音录制** — 一键录音，AI 自动转为文字（OpenAI Whisper）
- 💬 **对话记录** — 记录与朋友的对话，AI 生成摘要
- 🔒 **隐私保护** — Face ID 锁定 + AES-256 加密 + 本地优先存储
- 🤖 **AI 智能** — 自动摘要、情感分析、关键词提取

## 🛠️ 技术栈

- **Framework**: SwiftUI + SwiftData
- **Language**: Swift 6
- **AI Service**: OpenAI API (Whisper + GPT-4o)
- **Security**: CryptoKit (AES-256-GCM) + Keychain
- **Auth**: LocalAuthentication (Face ID / Touch ID)
- **Minimum**: iOS 17.0+

## 🚀 开始使用

### 前提条件
- Xcode 15.0+
- iOS 17.0+ 设备或模拟器
- OpenAI API Key（用于 AI 功能）

### 运行项目
1. 克隆仓库
2. 在 Xcode 中打开 `VibeMemo.xcodeproj`
3. 选择目标设备，点击运行
4. 在应用设置中输入你的 OpenAI API Key

## 📋 项目结构

```
VibeMemo/
├── App/            # 应用入口和主导航
├── Core/           # 核心模块
│   ├── Models/     # 数据模型 (SwiftData)
│   ├── Services/   # 核心服务 (AI, Audio, Crypto)
│   └── Extensions/ # Swift 扩展
├── Features/       # 功能模块
│   ├── Notes/      # 笔记功能
│   ├── Recording/  # 录音功能
│   ├── Conversations/ # 对话记录
│   └── Settings/   # 设置
└── Resources/      # 资源文件
```

## 🔐 隐私设计

- 所有数据加密存储在设备本地
- AI 处理使用 OpenAI API（数据不用于训练）
- Face ID / Touch ID 应用锁
- API Key 存储在 Keychain

## 📄 License

MIT License © 2026 doiya
