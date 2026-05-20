# GoatMarkdown

A lightweight macOS Markdown reader built with SwiftUI.

## Features

- 文件树侧栏，递归扫描 Markdown 文件并支持选中跳转
- Markdown 渲染（标题、段落、列表、引用、表格、代码块、图片、链接、分隔线）
- 搜索：当前命中实心高亮、其他命中半透明高亮，next/prev 自动滚动定位
- 书签：按块加书签，可设“自动打开默认书签”，下次打开文件时自动滚到该处
- 正文字号缩放，状态持久化到 UserDefaults
- Finder “Open With” 与外部文件 URL 打开

## Keyboard shortcuts

| 快捷键 | 行为 |
| --- | --- |
| `Cmd + F` / `/` | 打开/关闭搜索栏 |
| `Enter`（在搜索框内） | 跳到下一处命中 |
| `Cmd + =` / `Cmd + -` | 放大 / 缩小正文字号 |
| `Cmd + O` | 打开文件 |

## Requirements

- macOS 15.0+
- Xcode 16+

## Build & test

工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，`.xcodeproj` 不入库。clone 后先生成工程：

```sh
xcodegen generate
```

然后构建和测试：

```sh
xcodebuild build -project GoatMarkdown.xcodeproj -scheme GoatMarkdown -configuration Debug
xcodebuild test  -project GoatMarkdown.xcodeproj -scheme GoatMarkdown
```

构建产物位于 `~/Library/Developer/Xcode/DerivedData/GoatMarkdown-*/Build/Products/Debug/GoatMarkdown.app`。

## Project layout

- `GoatMarkdown/` — 应用源码（SwiftUI 视图、解析器、状态、主题、书签）
- `GoatMarkdownTests/` — 单元测试（解析、搜索高亮、书签、字号）
- `GoatMarkdown.xcodeproj/` — Xcode 工程（被 `.gitignore` 忽略，由 `project.yml` 生成）
- `project.yml` — XcodeGen 工程描述
