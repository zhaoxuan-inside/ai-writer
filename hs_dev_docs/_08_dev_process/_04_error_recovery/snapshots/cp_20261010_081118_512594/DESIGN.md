---
version: alpha
name: AI Writer
description: 个人创作者的本地优先长文写作客户端；主职是安静地写，AI 与同步克制出现
colors:
  primary: "#1C1C1C"
  secondary: "#6B6B6B"
  tertiary: "#2F6F5E"
  neutral: "#F4F1EA"
  surface: "#FFFEFB"
typography:
  h1:
    fontFamily: "Source Serif 4"
    fontSize: 40px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: -0.02em
  body-md:
    fontFamily: "Source Serif 4"
    fontSize: 18px
    fontWeight: 400
    lineHeight: 1.7
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 32px
  xl: 64px
rounded:
  sm: 2px
  md: 4px
  lg: 8px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    padding: 10px
---

# DESIGN.md — AI Writer

> Agent：实现 UI 前读本文件；手艺见 Skill `frontend_craft.md`。  
> 对标：**iA Writer**（气质改编，非像素克隆）。

## Overview

- **Audience**: 个人创作者（博客 / 公众号 / 小说 / 文案）
- **Primary job of the UI**: 让正文占据几乎全部注意力；工具在需要时才出现
- **Density**: airy（编辑区） / 侧栏与设置 balanced
- **Mood**: 纸感、安静、排版优先；像一台打字机而不是仪表盘

## Colors

- **Primary** `#1C1C1C`: 正文与关键文字
- **Secondary** `#6B6B6B`: 次要标签、字数、路径
- **Accent / Tertiary** `#2F6F5E`: 极少使用——主按钮、同步成功、AI「接受」；首屏预算约 3 处
- **Neutral** `#F4F1EA`: 窗口/侧栏底（暖纸）
- **Surface** `#FFFEFB`: 编辑纸面
- **Semantic**: error `#A33B2B` · warning `#9A6B2F` · success 用 tertiary · info 用 secondary
- **禁止**: 紫靛渐变、大面积霓虹 glow、重阴影卡片墙

## Typography

- **Body / 正文**: Source Serif 4（或平台优质衬线回退）；字号偏大（≈18）、行高 ≈1.7
- **UI chrome**: 窄用无衬线（如 IBM Plex Sans / 系统 UI）且字重克制
- **Mono**: 仅代码块
- **Rules**: 编辑区居中栏宽（约 34–40rem）；无花哨标题层级动画

## Layout

- **编辑主屏**: 弱铬顶栏（返回、文件名、可选字数）+ 全幅纸面；默认隐藏重工具条
- **库浏览**: 可折叠窄侧栏展示用户目录树；不抢编辑区
- **设置**: 分组列表，无仪表盘卡片墙
- **AI**: 选中时浮现轻量条；预览可在右侧窄栏或行内卡片，接受/拒绝清晰
- **同步**: 模态确认「整份覆盖」，无冲突合并 UI

## Elevation & Depth

- 几乎无阴影；用细分割线与纸面/侧栏色差分层
- 圆角偏小（2–4px），避免「超级 App」胶囊风

## Motion

- 侧栏折叠、AI 条出现：短、淡、位移小（≤200ms）
- 禁止持续脉冲、粒子、营销向转场

## Do

- 打开即进写作或目录，不先登录
- 空白态一句短文案 + 选目录/新建
- 键盘优先（快捷指令唤起 AI）

## Don't

- 默认展开 Quill 全量 Office 工具条
- 聊天式主界面、统计卡片条、多色标签云
- 把同步/账号做成首页英雄区
