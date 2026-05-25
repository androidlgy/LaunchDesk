# LaunchDesk

> 一个简洁、原生、好看的 macOS 应用启动器。重现新版 macOS 移除的 Launchpad。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ 功能

- 🚀 **全屏 Launchpad**：扫描 `/Applications`、`/System/Applications`、`~/Applications` 中所有 App
- 🔍 **拼音搜索**：输 `wx` 找到「微信」，支持英文 / 中文 / 拼音首字母 / 全拼
- 📁 **文件夹分组**：拖一个图标到另一个图标上自动建文件夹
- ⌨️ **键盘流**：方向键导航、⌘1-9 跳页、Enter 启动、Esc 收起
- 🖱️ **鼠标滚轮翻页** + 触控板二指滑
- 🎨 **5 种主题** + 毛玻璃强度可调
- ⚡ **轻量**：3.4 MB 占用，启动 <100ms

## 📥 下载

| 文件 | 大小 | 说明 |
| --- | --- | --- |
| [LaunchDesk-1.0.0.dmg](https://github.com/androidlgy/LaunchDesk/releases/download/v1.0.0/LaunchDesk-1.0.0.dmg) | 1.6 MB | 推荐，双击挂载后拖入 Applications |
| [LaunchDesk-1.0.0.zip](https://github.com/androidlgy/LaunchDesk/releases/download/v1.0.0/LaunchDesk-1.0.0.zip) | 1.3 MB | 解压即用 |

> 全部版本见 [Releases](https://github.com/androidlgy/LaunchDesk/releases)

## 🚀 安装

### DMG 方式（推荐）

1. 双击 `LaunchDesk-1.0.0.dmg` 挂载磁盘
2. 把 LaunchDesk 图标拖到 **Applications** 文件夹
3. 双击 LaunchDesk 启动

### ZIP 方式

1. 双击 `LaunchDesk-1.0.0.zip` 解压
2. 把 `LaunchDesk.app` 拖到 **`/Applications`**
3. 双击启动

---

## ⚠️ 第一次启动会出现："无法打开 LaunchDesk，因为 Apple 无法检查它是否包含恶意软件"

这是因为 LaunchDesk **未经过 Apple 公证（Notarization）**——这一步需要 99 美元/年的 Apple Developer 会员才能做。

**解决方法（任选一种）**：

### 方法 1：右键打开（推荐，一次即可）

1. 在 Finder 里**右键**点击 LaunchDesk.app（不是双击）
2. 选 **"打开"**
3. 弹窗里点 **"打开"**（不是"取消"或"移到废纸篓"）
4. 之后双击就可以正常启动

### 方法 2：在系统设置里允许

1. 双击 LaunchDesk → 看到警告 → 点"取消"
2. 打开 **系统设置 → 隐私与安全性**
3. 滚到底部"安全性"那一栏，会看到 **"已阻止 LaunchDesk"** → 点旁边的 **"仍要打开"**
4. 输入开机密码确认

### 方法 3：终端命令（高级）

```bash
sudo xattr -rd com.apple.quarantine /Applications/LaunchDesk.app
```

---

## 🎮 使用

### 唤起 LaunchDesk
- **菜单栏右上角**的 3×3 网格图标 → 点击
- 或按 **⌃⌥L**（Control + Option + L），可在偏好设置中改

### 操作
| 操作 | 效果 |
| --- | --- |
| 直接键入 | 进入搜索模式 |
| Enter | 启动选中应用 |
| ←→↑↓ | 网格中移动焦点 |
| ⌘1-9 | 跳到对应页 |
| Esc | 收起 |
| 鼠标滚轮 / 触控板二指 | 翻页 |
| 拖图标到另一个图标上 | 建文件夹 |
| 右键图标 | 收藏 / Finder 显示 / 隐藏 |

### 偏好设置
菜单栏图标 → 右键 → **偏好设置…**

可调：
- 全局快捷键（自定义录制）
- 网格列×行（5×4 ~ 10×8）
- 主题（深色/浅色/蓝紫渐变/通透/系统）
- 毛玻璃强度
- 是否显示收藏夹/最近使用条
- 哪些 App 隐藏不显示
- 开机自动启动

---

## 🔐 隐私

- LaunchDesk **完全不联网**，不收集任何数据
- 所有偏好和布局只保存在本地 `~/Library/Preferences/com.launchdesk.app.plist`
- 源码开源，你可以审计每一行

## 🛠️ 自己编译

```bash
git clone https://github.com/androidlgy/LaunchDesk.git
cd LaunchDesk
open LaunchDesk.xcodeproj
# 在 Xcode 里 ⌘R 即可
```

要求：macOS 13+，Xcode 15+。

## 📜 许可

MIT License — 免费使用、修改、再分发。

## 🐛 反馈

有问题/建议欢迎到 [Issues](https://github.com/androidlgy/LaunchDesk/issues) 提交。
