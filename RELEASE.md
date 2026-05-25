# LaunchDesk 上架 App Store 操作清单

> 本文档列出从开发完成到 App Store 上架的全部步骤。每完成一项打勾即可。

---

## 0. 前置条件

- [ ] 已加入 **Apple Developer Program**（个人 99 美金/年）
- [ ] 已安装 **Xcode 16.x 或更高**
- [ ] 已生成应用图标（`scripts/make_icon.swift` 可生成占位图，正式发布前请替换为正式设计稿）

```bash
# 一键生成占位图标到 AppIcon.appiconset
xcrun swift scripts/make_icon.swift
```

---

## 1. Xcode 工程配置

### 1.1 选择 AppStore Build Configuration

工程已经预置两组 Configuration：

| Configuration         | 用途                  | 沙盒 | 全局快捷键 | 卸载 App |
| --------------------- | --------------------- | ---- | ---------- | -------- |
| `Debug` / `Release`         | 本地自用、企业内分发  | ❌   | ✅ ⌥Space  | ✅       |
| `Debug-AppStore`            | 上架调试              | ✅   | ❌         | ❌       |
| `Release-AppStore`          | **上架打包用**        | ✅   | ❌         | ❌       |

打开 Xcode → 顶部 scheme → **Edit Scheme...** → Archive → Build Configuration 选 `Release-AppStore`。

### 1.2 修改 Bundle Identifier

`Signing & Capabilities` → `Bundle Identifier`：

```
com.launchdesk.app   →   com.<你的公司或域名反写>.launchdesk
```

> Bundle ID 要在 [App Store Connect](https://appstoreconnect.apple.com) 提前注册，且全局唯一。

### 1.3 设置签名

- Team: 选你的开发者账号
- Signing Certificate: `Apple Distribution`（自动生成）
- Provisioning Profile: `Automatic`

### 1.4 检查版本号

- Marketing Version (`CFBundleShortVersionString`): `1.0.0`
- Build Number (`CFBundleVersion`): `1`（每次重传至少 +1）

---

## 2. App Store Connect 准备

### 2.1 注册 App

[App Store Connect](https://appstoreconnect.apple.com) → My Apps → `+` → New App：

- Platform: macOS
- Name: **LaunchDesk**（28 字符内）
- Primary Language: Chinese (Simplified)
- Bundle ID: 同 Xcode
- SKU: `launchdesk-001`（任意，用于后台识别）

### 2.2 分类

- Primary Category: **Utilities**
- Secondary Category: **Productivity**

### 2.3 定价

| 选项     | 推荐                                                         |
| -------- | ------------------------------------------------------------ |
| 免费     | 触达更广，靠后续订阅/Pro 内购变现                            |
| 一次买断 | $1.99 / $3.99（启动器类常见档位，参考 Hyperdock $9.99）       |
| 订阅     | 不推荐，启动器属于一次性工具体验                             |

> 第一次上架推荐 **免费版本 + 后续 Pro 订阅**，先做留存再做变现。

### 2.4 隐私 (App Privacy)

由于我们 **不收集任何用户数据**，按以下回答：

- Do you collect data from this app? → **No**
- 无第三方 SDK → 无须额外声明
- `PrivacyInfo.xcprivacy` 已自动声明：
  - UserDefaults（CA92.1）
  - File timestamp（C617.1）
  - System boot time（35F9.1）

### 2.5 App 信息文案模板

**Name** (30 字符)
```
LaunchDesk - 应用启动器
```

**Subtitle** (30 字符)
```
找回你的 Launchpad
```

**Promotional Text** (170 字符，可随时改)
```
全屏网格、文件夹分组、模糊搜索 — 在 macOS 升级取消 Launchpad 后，重新拥有熟悉的启动体验。轻量、原生 SwiftUI、零数据收集。
```

**Description** (4000 字符，含关键词)
```
LaunchDesk 是 macOS 上的应用启动器，重现新版系统中已经移除的 Launchpad。

主要功能
• 全屏网格：自动扫描所有已安装的应用，按字母排序
• 文件夹分组：把图标拖到另一个图标上自动建文件夹
• 模糊搜索：输入任意字母即可快速过滤
• 多页布局：支持任意页数，方便分类
• 拖拽排序：自由调整图标位置，自动持久化
• 收藏与最近使用：常用 App 一键唤起
• 快速唤出：菜单栏点击或自定义快捷键

关于隐私
LaunchDesk 不收集任何数据、不联网、不内嵌广告或追踪 SDK。所有布局信息仅保存在你本地。

需要 macOS 13 或更高。
```

**Keywords** (100 字符，逗号分隔)
```
launcher,launchpad,启动器,启动台,应用,效率,菜单栏,快速启动,搜索,工具
```

**Support URL**: 你的 GitHub Issues 页或个人主页
**Marketing URL**（可选）

### 2.6 截图（必须）

| 尺寸                     | 数量   | 备注                  |
| ------------------------ | ------ | --------------------- |
| **2880 × 1800** (主)     | 1–10 张 | 最重要，一定要好看    |
| 2560 × 1600              | 可选   |                       |
| 1440 × 900               | 可选   |                       |

> 建议 5 张：主界面 / 文件夹 / 搜索 / 多页 / 设置。
> 用 macOS Sonoma+ 自带 `⇧⌘5` 截图，再用 Figma/Sketch 加文字说明。

---

## 3. 打包上传

### 3.1 Archive

```
Xcode → Product → Archive
```

Scheme 必须使用 `Release-AppStore`。Archive 完成后 Organizer 会自动打开。

### 3.2 Validate（强烈推荐）

Organizer → 选中刚才的 Archive → **Validate App** → 选 `App Store Connect` → 等几分钟。
任何问题（图标缺失、Bundle ID 不匹配、缺隐私清单）都会在这里报。

### 3.3 Distribute

Validate 通过后，点击 **Distribute App** → `App Store Connect` → `Upload` → 等待。

上传成功后，到 App Store Connect → 你的 App → TestFlight & App Store → 选刚上传的构建版本，关联到提审版本。

### 3.4 Submit for Review

- 填写所有字段 → **Add for Review** → **Submit**
- 一般 24–48 小时审核完成

---

## 4. 常见审核驳回原因 & 对策

| 原因                                         | 对策                                              |
| -------------------------------------------- | ------------------------------------------------- |
| `2.1 App Completeness` 启动崩溃              | 在 Release-AppStore 配置下完整跑一遍              |
| `4.0 Design — Spam` 启动器与 Launchpad 重复  | 在描述里强调差异：搜索、分组、跨版本、自定义     |
| `5.1.1 Privacy` 没有隐私清单                  | `PrivacyInfo.xcprivacy` 已包含                    |
| `2.5 Sandbox` 用了不允许的 API               | 已通过 `APPSTORE` 条件编译禁用 trashItem / Carbon |
| `2.4.5 macOS` 提示需要在 Mac App Store 测试  | 用 `Release-AppStore` Archive 后跑一遍             |

---

## 5. 上架后

- [ ] 准备 1.0.1 修复版（首次提审常被打回 1–2 次）
- [ ] 监控 App Store Connect 评分
- [ ] 收集用户反馈（GitHub Issues）
- [ ] 1.1 版本规划：自定义快捷键、CoreSpotlight 集成、iCloud 同步布局

---

祝上架顺利 🎉
