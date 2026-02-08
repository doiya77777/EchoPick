# EchoPick 开发文档

> 核心参考文档。涵盖架构设计、功能开发流程、UI/UX 规范、测试策略、真机部署。

---

## 1. 核心设计理念

### 1.1 产品哲学

**原始文本是资产（Echo），离散数据是索引（Pick）。**

- 录音和转录文本是不可替代的一手资料，永远优先保存和展示
- AI 分析是辅助手段，不是核心功能；提取结果可随时重新生成
- 用户永远可以回到原始音频和文本，AI 不会"吃掉"原始数据

### 1.2 架构原则

| 原则 | 说明 |
|------|------|
| **本地优先** | 所有数据存设备本地（SwiftData），iCloud 仅做同步，不依赖任何自建后端 |
| **隐私第一** | API Key 存 Keychain，音频 TLS 传输，服务端不留存 |
| **UI 不阻塞** | 录音停止后立即保存记录、恢复 UI，AI 分析在后台静默进行 |
| **可回退** | AI 分析失败不影响已保存的录音和文本，随时可重新分析 |
| **极简交互** | 一个按钮开始录音，放口袋就行。减少认知负担 |

### 1.3 数据模型

```
EchoRecord (资产)
├── id: UUID
├── audioSegments: [String]     ← 音频文件路径（每 5 min 自动分段）
├── fullTranscript: String      ← 完整转录文本（最核心的资产）
├── summary: String?            ← AI 一句话摘要
├── duration: TimeInterval
├── createdAt: Date
├── isProcessing: Bool
└── processingStatus: String?

Pick (索引)
├── id: UUID
├── recordId: UUID              ← 关联的 EchoRecord
├── pickType: String            ← topic / key_fact / action_item / sentiment / key_metric
├── content: String
├── timestampOffset: TimeInterval
└── contextAnchor: String       ← 原文锚点，用于溯源高亮
```

---

## 2. 项目架构

### 2.1 目录结构

```
EchoPick/
├── App/                          # 应用层
│   ├── EchoPickApp.swift         # @main 入口，SwiftData 容器
│   ├── ContentView.swift         # Tab 导航（录音 / 记录 / 看板 / 设置）
│   ├── LockScreenView.swift      # Face ID 锁屏
│   └── AppState.swift            # 全局状态（认证、录音状态）
│
├── Core/                         # 核心层
│   ├── Models/
│   │   ├── EchoRecord.swift      # SwiftData @Model
│   │   └── Pick.swift            # SwiftData @Model + PickType enum
│   ├── Services/
│   │   ├── AudioEngine.swift     # AVAudioEngine 录音引擎
│   │   ├── StreamingASRService.swift  # 火山引擎 Seed ASR（WebSocket 流式）
│   │   ├── SeedASRService.swift  # ASR WebSocket 协议实现
│   │   ├── WhisperService.swift  # OpenAI Whisper（备用）
│   │   ├── PickExtractor.swift   # Seed LLM JSON Mode 提取
│   │   ├── StorageService.swift  # SwiftData CRUD
│   │   └── APIKeyStore.swift     # Keychain 存取
│   └── Extensions/
│       ├── DesignSystem.swift    # DS.Colors / DS.Spacing / DS.Font
│       ├── Color+Hex.swift       # Color(hex:) 扩展
│       └── Date+Display.swift    # 日期格式化
│
├── Features/                     # 功能模块（MVVM）
│   ├── Listener/                 # 录音
│   │   ├── Views/
│   │   │   ├── ListenerView.swift
│   │   │   └── WaveformView.swift
│   │   └── ViewModels/
│   │       └── ListenerViewModel.swift
│   ├── History/                  # 记录列表
│   ├── Detail/                   # 详情（音频+文本+AI）
│   ├── Dashboard/                # 今日看板
│   └── Settings/                 # 设置
│
├── Resources/
│   └── Assets.xcassets/          # 颜色资产 + App Icon（深浅两套）
│
└── Tests/
    ├── EchoPickIntegrationTests.swift
    └── Resources/test_audio.m4a
```

### 2.2 MVVM 分层

```
View（SwiftUI）
  ↓ @StateObject
ViewModel（@MainActor ObservableObject）
  ↓ 调用
Service（AudioEngine / ASR / PickExtractor / Storage）
  ↓ 操作
Model（SwiftData @Model）
```

**规则：**
- View 只负责布局和交互，不包含业务逻辑
- ViewModel 持有 Service 实例，协调数据流
- Service 是无状态单例或实例，负责具体操作
- Model 是纯数据结构，通过 SwiftData 持久化

### 2.3 关键数据流

```
录音流程:
  用户点击 → AudioEngine.startSession()
           → AVAudioEngine tap → PCM 流
           → StreamingASRService.sendAudio() → WebSocket
           → ASR 返回 → confirmedUtterances / liveTranscript
           
  用户停止 → sendLastPacket() → 等待最终结果
           → audioEngine.stopSession() → 返回 segments + duration
           → 构建转录文本 → 保存 EchoRecord（UI 立即恢复）
           → 后台 Task → PickExtractor.extract() → 保存 Picks
```

---

## 3. 功能开发指南

### 3.1 新增功能的标准流程

1. **Model** — 如果需要新数据，先在 `Core/Models/` 添加或修改 SwiftData 模型
2. **Service** — 在 `Core/Services/` 实现具体逻辑。Service 不依赖 UI
3. **ViewModel** — 在对应 Feature 的 `ViewModels/` 创建 `@MainActor` 类
4. **View** — 在 `Views/` 实现 SwiftUI 界面，通过 `@StateObject` 绑定 ViewModel
5. **Tests** — 在 `Tests/` 添加单元测试。网络相关加 `try skipIfNoXXXKey()` 保护

### 3.2 添加新的 Pick 类型

1. 在 `Pick.swift` 的 `PickType` enum 添加新 case
2. 给新 case 添加 `label`、`icon`、`colorHex` 属性
3. 在 `DesignSystem.swift` 的 `DS.Colors` 添加语义色（如果需要）
4. 在 `PickExtractor.swift` 的 LLM prompt 中添加新类型的提取指令
5. 在 `PickCardView.swift` 的 `typeColor` switch 添加新 case
6. 在 `HistoryListView.swift` 的 `pickTypeColor` switch 添加新 case
7. 在 `EchoDetailViewModel` 添加过滤 computed property

### 3.3 添加新的设置项

1. 在 `SettingsViewModel` 添加 `@Published` 属性和存取方法
2. 如果涉及安全数据，用 `APIKeyStore`（Keychain）
3. 在 `SettingsView.swift` 的对应 section 添加 UI

---

## 4. UI/UX 设计规范

### 4.1 设计语言

**关键词：** 极简、克制、自适应、无 emoji

参考：柚子鲸个人博客风格 — 大留白、细边框、暖色调

| 要素 | 规范 |
|------|------|
| **背景** | 浅色 `#F5F0E6`（奶油），深色 `#111115`（近黑） |
| **卡片** | 浅色 `#FFFDF8`（暖白），深色 `#1C1C21`（深灰） |
| **边框** | 1px，`DS.Colors.border`（12% 透明度） |
| **圆角** | 小 8pt / 中 12pt / 大 16pt |
| **间距** | 基于 4pt 网格：4 / 8 / 16 / 24 / 32 / 48 |
| **图标** | 只用 SF Symbols，不用 emoji |
| **动画** | 轻微、克制。`.easeInOut` 0.2-0.3s |

### 4.2 排版系统

**核心规则：** 中文用系统默认字体（PingFang SC），英文数字可用 `.rounded`

| 用途 | 调用 | 效果 |
|------|------|------|
| 大标题 | `DS.Font.title()` | 24pt Bold |
| 副标题 | `DS.Font.headline()` | 18pt Bold |
| Section 标题 | `DS.Font.section()` | 15pt Bold |
| 正文 | `DS.Font.body()` | 14pt Regular |
| 正文加粗 | `DS.Font.bodyBold()` | 14pt Semibold |
| 辅助文字 | `DS.Font.caption()` | 12pt Regular |
| 标签 | `DS.Font.tag()` | 11pt Medium |
| 数字 | `DS.Font.number()` | 18pt Bold Rounded |
| 计时器 | `DS.Font.timer()` | 48pt UltraLight Rounded |
| 等宽 | `DS.Font.mono()` | 11pt Monospaced |

**不要这样做：**
```swift
// ❌ rounded 和中文混用，视觉割裂
.font(.system(size: 14, design: .rounded))

// ✅ 中文正文用默认字体
.font(DS.Font.body())

// ✅ 纯数字场景用 rounded
.font(DS.Font.number())
```

### 4.3 颜色语义

| 名称 | 用途 |
|------|------|
| `DS.Colors.bg` | 页面背景 |
| `DS.Colors.bgCard` | 卡片背景 |
| `DS.Colors.text` | 主文字 |
| `DS.Colors.textSecondary` | 次要文字 |
| `DS.Colors.textMuted` | 淡化文字（时间戳等） |
| `DS.Colors.border` | 边框 |
| `DS.Colors.accentSoft` | 柔和强调背景（按钮底色等） |
| `DS.Colors.topicColor` | 话题类 Pick — 靛蓝 `#5B6ABF` |
| `DS.Colors.actionColor` | 待办类 Pick — 红色 `#D9534F` |
| `DS.Colors.factColor` | 信息类 Pick — 琥珀 `#E5A100` |

所有颜色通过 Asset Catalog 的 Color Set 实现自适应深浅色，不要硬编码 light/dark 判断。

### 4.4 通用组件

```swift
// 卡片
VStack { ... }
    .cardStyle()                    // 默认 16pt 圆角
    .cardStyle(radius: DS.Radius.md) // 自定义圆角

// 标签药丸
Text("3 条")
    .pillTag(color: DS.Colors.topicColor)
```

### 4.5 App Icon

两套自适应 icon（iOS 18+）：
- **浅色模式：** 奶油底 + 深蓝侧条 + 琥珀黄中间条
- **深色模式：** 深蓝底 + 浅色侧条 + 琥珀黄中间条

文件位于 `Resources/Assets.xcassets/AppIcon.appiconset/`

---

## 5. 测试策略

### 5.1 测试分类

| 类型 | 环境 | 说明 |
|------|------|------|
| **单元测试** | 模拟器 | 不依赖硬件/网络，测试纯逻辑 |
| **集成测试** | 模拟器+网络 | 需要 API Key，测试完整管线 |
| **真机测试** | iPhone 真机 | 测试录音、音频引擎、后台行为 |

### 5.2 单元测试

在 `EchoPick/Tests/` 编写。当前覆盖：

- **PCM 累积逻辑** — 验证音频数据分块正确（精确 chunk / 不足 chunk / 多 chunk + 余数）
- **音频电平计算** — 验证 `AudioEngine.calcLevel()` 输出合理范围
- **文件管理** — 录音目录创建/删除、会话大小计算
- **Keychain 存取** — API Key 保存/读取/删除
- **AudioEngine 初始状态** — 模拟器检测、初始属性值
- **ASR 初始状态** — 连接状态、空数据验证

命令行运行：
```bash
cd /Users/doiya/vibe_project
xcodebuild test \
  -project EchoPick.xcodeproj \
  -scheme EchoPick \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "Test Case|passed|failed"
```

### 5.3 集成测试

需要在本地创建 key 文件（不会提交到 git）：

```bash
echo "YOUR_ASR_APP_KEY" > ~/.echopick_test_asr_appkey
echo "YOUR_ASR_ACCESS_KEY" > ~/.echopick_test_asr_accesskey
echo "YOUR_LLM_KEY" > ~/.echopick_test_doubao_llm_key
```

集成测试会自动跳过没有 key 的用例：
- **ASR 连接测试** — 验证 WebSocket 握手和连接状态
- **ASR 音频测试** — 发送 `test_audio.m4a` 验证转录结果非空
- **全管线测试** — ASR 转录 → LLM 提取 → 验证摘要和 Picks

### 5.4 编写测试的规范

```swift
// 1. 单元测试不需要保护
func testPCMAccumulation_exactChunk() {
    // 直接测试
}

// 2. 需要网络的测试加 skip 保护
func testStreamingASRConnection() async throws {
    try skipIfNoASRKeys()       // 没有 key 自动跳过
    // ... 测试逻辑
}

// 3. 测试命名：test[功能]_[场景]
func testPCMAccumulation_multipleChunks() { }
func testAudioEngineInitialState() async { }
```

---

## 6. 真机测试与部署

### 6.1 环境要求

- **设备：** iPhone（iOS 17.0+）
- **连接：** USB 或同一 WiFi（需先 USB 配对）
- **证书：** 自动签名（`CODE_SIGN_STYLE: Automatic`）
- **Team ID：** `ZLX96NXN3W`

### 6.2 设备 ID 查询

```bash
xcrun devicectl list devices 2>&1 | grep -E "identifier|name"
```

当前测试设备 ID：`DF3A7D40-6966-53F9-B682-B622FEC508EA`

### 6.3 构建 + 安装（一键流程）

```bash
# 1. 生成 Xcode 项目（project.yml 变更后需要）
cd /Users/doiya/vibe_project && xcodegen generate

# 2. 构建 Release（真机）
xcodebuild -project EchoPick.xcodeproj \
  -scheme EchoPick \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -allowProvisioningUpdates \
  CONFIGURATION_BUILD_DIR=/Users/doiya/vibe_project/build-device \
  build 2>&1 | grep -E "error:|BUILD" | tail -15

# 3. 安装到设备
xcrun devicectl device install app \
  --device DF3A7D40-6966-53F9-B682-B622FEC508EA \
  /Users/doiya/vibe_project/build-device/EchoPick.app

# 4. 启动应用
xcrun devicectl device process launch \
  --device DF3A7D40-6966-53F9-B682-B622FEC508EA \
  com.doiya.echopick
```

### 6.4 真机测试重点

模拟器 **无法测试** 的功能：

| 功能 | 原因 | 测试方法 |
|------|------|----------|
| **麦克风录音** | 模拟器无物理麦克风 | 真机上点击录音按钮，对着说话 |
| **后台录音** | 模拟器后台行为不完整 | 录音中按 Home 键，检查回来后录音是否继续 |
| **音频分段** | 需要真实 5 分钟录音 | 长时间录音测试分段文件正确生成 |
| **Face ID** | 模拟器只能软件模拟 | 真机验证生物识别流程 |
| **音频播放** | 依赖真实音频会话 | 在详情页点击播放按钮 |
| **系统深浅色切换** | 模拟器可以但真机更真实 | 系统设置切换外观模式 |
| **低电量/内存** | 模拟器不模拟 | 长时间后台录音观察内存使用 |

### 6.5 调试真机日志

```bash
# 实时查看设备日志
xcrun devicectl device info processes \
  --device DF3A7D40-6966-53F9-B682-B622FEC508EA 2>&1 | grep -i echo
```

也可以在 Xcode 中 `Window → Devices and Simulators` 查看设备日志。

### 6.6 常见问题

**Q: Build 成功但安装失败？**
A: 检查设备是否信任了开发证书。设置 → 通用 → VPN 与设备管理 → 信任

**Q: 录音没有声音？**
A: 检查 Info.plist 的 `NSMicrophoneUsageDescription` 是否存在，用户是否授权了麦克风

**Q: Tab Bar 闪黑？**
A: `ContentView.init()` 必须同时配置 `standardAppearance` 和 `scrollEdgeAppearance`

---

## 7. 构建配置

### 7.1 XcodeGen (`project.yml`)

项目使用 XcodeGen 管理，不直接编辑 `.xcodeproj`：

```bash
# 修改 project.yml 后重新生成
xcodegen generate
```

关键配置：
- **Swift 版本：** 6.0
- **最低部署：** iOS 17.0
- **Bundle ID：** `com.doiya.echopick`
- **显示名称：** 拾响
- **后台模式：** `audio`（后台录音）
- **权限：** 麦克风、Face ID、语音识别

### 7.2 技术栈版本

| 组件 | 版本/服务 |
|------|-----------|
| SwiftUI | iOS 17+ |
| SwiftData | iOS 17+ |
| AVAudioEngine | 实时 PCM 捕获 |
| 语音识别 | 火山引擎 Seed ASR 2.0（WebSocket 流式） |
| 智能提取 | 火山引擎 Seed LLM（JSON Mode） |
| 密钥存储 | iOS Keychain |
| 认证 | LocalAuthentication（Face ID / Touch ID） |
| 项目管理 | XcodeGen |

---

## 8. 代码审查清单

提交代码前检查：

- [ ] 所有中文文本用 `DS.Font.body()` 等默认字体，不用 `.rounded`
- [ ] 所有颜色用 `DS.Colors.xxx`，不硬编码 hex 值
- [ ] 不使用 emoji 作为 UI 元素（用 SF Symbols）
- [ ] 新的 `PickType` case 在所有 switch 中都处理了
- [ ] `@MainActor` 标注在所有 ViewModel 上
- [ ] Service 调用不阻塞 UI（用 `Task {}` 后台执行）
- [ ] 敏感数据（API Key）走 Keychain 存取
- [ ] 模拟器上 `xcodebuild test` 通过
- [ ] 真机 build + install 通过

---

*最后更新：2026-02-09*
