# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

本仓库是一个 Claude Code Skill 集合，用于赛意 SMOM 平台（.NET 6.0 MES + SIE 自研框架）开发辅助。参考 [Superpower](https://github.com/obra/superpowers) 设计，所有 skill 放在 `skills/` 目录下。

## 目录结构

```
sie-smom/
├── .claude-plugin/
│   ├── plugin.json         ← plugin 元数据
│   └── marketplace.json    ← marketplace 声明（plugins 列表）
├── skills/
│   └── sie-smom/           ← 实际 skill（SKILL.md + references/）
│       ├── SKILL.md         ← Skill 入口（平台本质、防幻写协议、10条红线、路由表）
│       └── references/      ← 参考底库（精炼规则）
│           ├── 01-architecture.md ～ 12-pda-frontend.md  ← 精炼规则
├── README.md
├── CLAUDE.md
├── LICENSE
├── update.ps1              ← 一键更新脚本（Windows）
└── update.sh               ← 一键更新脚本（Unix）
```

## 核心设计

### 防幻写协议（SKILL.md 第2节）
本 skill 的核心约束：AI 写 SMOM 代码前必须查参考底库，不臆造框架 API。所有结论标注来源。

### 10条强制红线（SKILL.md 第3节）
1. 禁止前端直访数据库
2. 禁止无条件全表查询
3. 大集合 IN 查询必须分批（SplitContains）
4. 每个查询带 IS_PHANTOM = 0
5. JS 文件必须设为嵌入资源
6. 实体属性用 Property<T> 注册
7. 国际化用 .L10N() / .t()
8. 新建实体同步产出建表脚本
9. Controller 继承 DomainController
10. 非重写视图方法属性显式 .Readonly().Show()

## 常用命令

### 发布新版本

推送 `main` 分支时，GitHub Actions 自动完成：

1. 读取 `plugin.json` 当前版本号，自动递增 patch（如 `1.0.6` → `1.0.7`）
2. 更新 `plugin.json` 和 `marketplace.json` 中的版本号
3. 创建 `v1.0.7` 标签
4. 生成 Release Notes（基于提交日志）
5. 创建 GitHub Release

> 提交信息包含 `[skip release]` 可跳过自动发布。

### 添加新 Skill
1. 在 `skills/` 下创建目录，如 `skills/xxx-skill/`
2. 目录根包含 `SKILL.md` 作为入口
3. 在 `.claude-plugin/marketplace.json` 的 `plugins` 数组追加条目
4. 更新 `README.md` 添加介绍
5. 提交 PR

### 更新已有 Skill 内容
修改 `skills/sie-smom/` 下的文件后：
```bash
git add -A
git commit -m "描述修改内容"
git push origin main
# GitHub Actions 会自动发布新版本 Release
```

## 参考底库来源

- **精炼规则**（references/01-12）：个人经验整理的规则，含【禁止项/错误示例/正确示例】