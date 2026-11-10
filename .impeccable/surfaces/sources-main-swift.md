# Surface Brief: Sources/main.swift

## Scope & Visitor Mode
Mode: operate
Surface: Main App Window (Default App macOS Desktop UI)

## Audience, Job & Constraints
Audience: macOS 开发者、系统高级用户与日常效率追求者。
Job: 高效检视全局文件格式接管状态，一键或批量修改默认应用关联。
Constraints: 100% 纯 Swift 6 + SwiftUI + AppKit 原生代码，适配 macOS 12 Monterey 至 macOS 15 Sequoia 及更高版本；零后台守护进程；遵循 Apple HIG 原生规范。

## Direction contract

THESIS: 彻底拒绝“网页套壳式”的粗糙拼凑感与杂乱分隔线，回归现代 macOS Sonoma / Sequoia 原生美学与桌面工具的极致轻盈与敏捷。
OWN-WORLD: 深度采用 macOS 原生设计语言：侧边栏半透明毛玻璃材质（Vibrancy / NSVisualEffectView）、系统原生统一标题栏（Unified Compact Toolbar）、系统语义色彩与分层（Label / SecondaryLabel / SystemGreen）、精制 SF Symbols 与流畅弹性动效。
STORY: 用户一眼洞悉目标应用的格式支持全貌与生效进度；精准筛选未生效格式，一键安全绑定；在格式直查中毫秒级反查并从系统原生候选菜单中随心切换。
FIRST VIEWPORT: 顶部统一原生工具栏承载品牌、模式切换与动态更新胶囊；左侧高质感系统侧边栏融合分类筛选、搜索与应用列表；右侧结构化 Hero 指标与对齐严谨的三列格式管理列表。
FORM: 经典双栏结构精修与原生统一样式工具栏，seed: none (pinned)
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
