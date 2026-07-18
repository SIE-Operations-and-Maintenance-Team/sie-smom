#!/bin/bash
# SIE SMOM Skills 一键更新工具（Unix/macOS）
# 扫描 ~/.claude/skills/ 下所有 Git 仓库类型的 skill，自动拉取最新版本。
#
# 用法:
#   ./update.sh
#   ./update.sh --org SIE-Operations-and-Maintenance-Team
#   ./update.sh --force

SKILLS_DIR="$HOME/.claude/skills"
ORG=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --org) ORG="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

if [ ! -d "$SKILLS_DIR" ]; then
    echo "❌ 未找到 skills 目录: $SKILLS_DIR"
    exit 1
fi

UPDATED=0
SKIPPED=0
ERRORS=()

echo "=== SIE SMOM Skills 更新工具 ==="
echo "扫描目录: $SKILLS_DIR"
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")

    if [ ! -d "$skill_dir/.git" ]; then
        continue
    fi

    remote_url=$(git -C "$skill_dir" remote get-url origin 2>/dev/null)
    if [ -z "$remote_url" ]; then
        continue
    fi

    if [ -n "$ORG" ] && ! echo "$remote_url" | grep -q "$ORG"; then
        continue
    fi

    echo "  [$skill_name]"

    status=$(git -C "$skill_dir" status --porcelain 2>/dev/null)
    if [ -n "$status" ] && [ "$FORCE" = false ]; then
        echo "    ⚠️  有本地修改，跳过（用 --force 会覆盖）"
        ((SKIPPED++))
        continue
    fi

    if [ -n "$status" ] && [ "$FORCE" = true ]; then
        echo "    ⚠️  发现本地修改，执行 git reset --hard ..."
        git -C "$skill_dir" reset --hard HEAD 2>/dev/null
    fi

    result=$(git -C "$skill_dir" pull --ff-only 2>&1)
    if [ $? -eq 0 ]; then
        if echo "$result" | grep -q "Already up to date"; then
            echo "    ✅ 已是最新"
        else
            echo "    ✅ 已更新"
            ((UPDATED++))
        fi
    else
        echo "    ❌ 更新失败: $result"
        ERRORS+=("$skill_name: $result")
    fi
done

echo ""
echo "=== 完成 ==="
echo "已更新: $UPDATED | 已跳过: $SKIPPED | 失败: ${#ERRORS[@]}"
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "失败详情:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
fi