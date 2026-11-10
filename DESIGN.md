---
name: Default App
description: 现代原生 macOS 文件关联架构管家设计规范
colors:
  accent: "systemAccent"
  success: "#34C759"
  warning: "#FF9500"
  window-bg: "NSColor.windowBackgroundColor"
  control-bg: "NSColor.controlBackgroundColor"
  sidebar-material: "NSVisualEffectView.Material.sidebar"
  titlebar-material: "NSVisualEffectView.Material.titlebar"
typography:
  headline:
    fontFamily: "SF Pro Rounded, system"
    fontSize: "19pt"
    fontWeight: 700
  body:
    fontFamily: "SF Pro Text, system"
    fontSize: "12.5pt"
    fontWeight: 500
  mono-badge:
    fontFamily: "SF Mono, monospace"
    fontSize: "12pt"
    fontWeight: 700
  caption:
    fontFamily: "SF Pro Text, system"
    fontSize: "10.5pt"
    fontWeight: 400
rounded:
  sm: "5px"
  md: "7px"
  lg: "13px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "#ffffff"
    rounded: "{rounded.md}"
    padding: "6px 12px"
---

# Design System: Default App

<!-- impeccable:design-schema 1 -->

## Overview

Default App 是纯正遵循 macOS Human Interface Guidelines (HIG) 的桌面管理工具。本系统追求极致原生响应度、通透轻盈的半透明材质（Vibrancy）与沉浸式操作体验，杜绝粗糙的网页套壳感。

## Colors

- **系统语义色（System Semantic Colors）**：严格依循 Apple HIG，动态适配深色（Dark Mode）与浅色（Light Mode）外观。
  - 强调色：系统原生 Accent Color（`Color.accentColor`）。
  - 生效状态：System Green（`#34C759`，`Color.green`）。
  - 警告与提示：System Orange（`#FF9500`，`Color.orange`）。
  - 次级文字：`Color.secondary`（动态语义分级）。

## Typography

- **San Francisco 系列**：
  - 应用标题：SF Pro Rounded（粗体，亲和且具辨识度）。
  - 核心正文：SF Pro Text（500/600 字重，保证在不同尺寸屏幕上的极致可读性）。
  - 扩展名与标识符：SF Mono（用于文件后缀与 UTI 声明，严禁作为装饰性泛滥使用）。

## Layout

- **双栏分栏布局（Master-Detail Split View）**：
  - 窗口最小尺寸：920 × 640 pt。
  - 顶部工具栏：统一样式（Unified Header Bar），承载品牌信息、分段控制器（Segmented Tab）与动态更新药丸。
  - 左侧侧边栏：宽度 285 pt（支持 250 ~ 350 pt 动态拖拽），采用 `NSVisualEffectView.sidebar` 毛玻璃半透明底色。
  - 右侧主工作区：高质感 Hero 仪表卡片 + 严整对齐的三列格式操作矩阵。

## Elevation & Depth

- **柔和层次（Subtle System Depth）**：
  - 规避零模糊硬阴影（Zero-blur offset shadow）与纯装饰光晕。
  - 悬浮卡片与图标采用微阴影（Radius: 3~6 pt, Y: 1~2 pt, Opacity: 0.08~0.14）。
  - 边框采用 0.5~0.8 pt 细微语义描边（`Color.primary.opacity(0.06~0.08)`）。

## Shapes

- 采用 Apple Continuous Corner（连续平滑圆角）：
  - 列表行卡片：7 pt
  - 格式等宽药丸：5 pt
  - Hero 大图标：13 pt

## Components

1. **统一导航头（Unified Navigation Bar）**：
   - 居中 Segmented Control，左右分别对齐品牌区与状态胶囊。
2. **侧边栏应用卡片（AppCardRow）**：
   - 图标 + 名称 + BundleId + 格式数量胶囊，支持 Hover 微交互与原生选中态高亮。
3. **格式行项（ExtensionRowItem）**：
   - 结构化 3 列布局：勾选框 + 等宽后缀胶囊 + 本地化描述/UTI + 原生应用下拉选择菜单。
4. **格式反查聚焦面板（ExtensionLookupView）**：
   - 聚焦反查输入框 + 预设常见格式快捷药丸 + 候选应用对比卡片。

## Do's and Don'ts

### Do's
- 始终使用系统语义颜色与系统材质，保障深浅色自动优雅适配。
- 保证可点击区域舒适，字体阶梯清晰。
- 动效全部采用 Apple 官方推荐的 Spring 阻尼曲线。

### Don'ts
- 严禁在无必要场景使用纯黑边框或粗线 `Divider()`。
- 严禁在标题上方添加无意义的 Eyebrow/Kicker 标签。
- 严禁使用虚假的未声明纯装饰毛玻璃或渐变文字。
