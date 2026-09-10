# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

本仓库是赛意 SMOM 平台（.NET 6.0 MES + SIE 自研框架）开发的 **Claude Code Skill**：`skills/sie-smom/` 防幻写参考底库。

- **防幻写参考底库**（`skills/sie-smom/`）：25 份文档（编号 01-23，13 号历史删除；18 号 Web 命令配方按任务域拆为 4 份）：01-07、12 精炼规则、08-11 与 14-17 数据库规范、18-23 配方库（蒸馏自 SMOM 开发手册 2026-08 版，共 76 篇配方）。AI 写代码前先查证，不臆造框架 API。
- 参考底库已借鉴平台外部规范精华（实战陷阱、防臆造 API、前端进阶等），按本库【禁止/错误示例/正确示例】风格融入各 references。

参考 [Superpower](https://github.com/obra/superpowers) 设计。

## 目录结构

```
sie-smom/
├── .claude-plugin/
│   ├── plugin.json         ← plugin 元数据
│   └── marketplace.json    ← marketplace 声明（plugins 列表）
├── skills/
│   └── sie-smom/           ← 实际 skill（SKILL.md + references/ 01-23）
│       ├── SKILL.md        ← Skill 入口（平台本质、防幻写协议、14 条红线、路由表）
│       └── references/     ← 参考底库（25 份：01-07、12 精炼规则 / 08-11、14-17 数据库规范 / 18-23 配方库）
│           ├── 01-architecture.md ～ 17-postgresql-table.md
│           └── 18-web-commands-*.md（4 份）～ 23-problems.md
├── README.md
├── CLAUDE.md
├── newbie-guide.md        ← 新人上手指南
├── LICENSE
├── update.ps1              ← 一键更新脚本（Windows）
└── update.sh               ← 一键更新脚本（Unix）
```

## 核心设计

### 防幻写协议（skills/sie-smom/SKILL.md 第2节）
AI 写 SMOM 代码前必须查参考底库，不臆造框架 API。所有结论标注来源。
查证顺序：`skills/sie-smom/references/`（精炼、优先）→ 项目实际代码。

### 14条强制规则（红线，skills/sie-smom/SKILL.md 第3节）
1. 禁止前端直访数据库
2. 禁止无条件全表查询
3. 大集合 IN 查询必须分批（SplitContains）
4. 每个查询带 IS_PHANTOM = 0；枚举属性用枚举类而非 int
5. JS 文件必须设为嵌入资源（EmbeddedResource + None Remove）
6. 实体属性用 Property<T> 注册
7. 国际化用 .L10N() / .t()
8. 新建实体同步产出建表脚本（四库各一套）
9. Controller 继承 DomainController；强关联子表用 ChildrenProperty，弱关联用 AttachChildrenProperty
10. 非重写视图方法属性显式 .Readonly().Show()；FormEdit 弹窗 / InlineEdit 行内
11. using 指令完整性（SIE.*、System.*、RT.Service、RF、DB）
12. FirstOrDefault 仅单参数重载（EagerLoadOptions）
13. Criteria 类独立文件（继承 Criteria，[QueryEntity] + [Serializable]）
14. 数据传输类必须标注 [Serializable]

## 常用命令

### 发布新版本

推送 `main` 分支时，GitHub Actions 自动完成：

1. 读取 `plugin.json` 当前版本号，自动递增 patch
2. 更新 `plugin.json` 和 `marketplace.json` 中的版本号
3. 创建 `vX.Y.Z` 标签
4. 生成 Release Notes（基于提交日志）
5. 创建 GitHub Release

> 提交信息包含 `[skip release]` 可跳过自动发布。重大变更可手动改版本号后提交。

### 更新 Skill 内容
修改 `skills/sie-smom/` 下的文件后：
```bash
git add -A
git commit -m "描述修改内容"
git push origin main
# GitHub Actions 会自动发布新版本 Release
```

## 参考底库来源

- **精炼规则与数据库规范**（`skills/sie-smom/references/` 01-17）：个人经验整理的规则，含【禁止项/错误示例/正确示例】，防幻写优先查证源
- **配方库**（`skills/sie-smom/references/` 18-23）：蒸馏自 SMOM 开发手册 2026-08 版（Web 命令 22 篇 / Web 行为与编辑器 13 篇 / Web 前端 12 节 / WPF 6 组 / 服务端工具 12 节 / 问题库 11 节）
- **外部规范精华**：平台外部一本通规范与实战陷阱的**借鉴精华**（防臆造 API、前端进阶、实体陷阱等），已按本库风格融入各 references，不保留独立副本