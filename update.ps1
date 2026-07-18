<#
.SYNOPSIS
    SIE SMOM Skills 一键更新工具
.DESCRIPTION
    扫描 ~/.claude/skills/ 下所有 Git 仓库类型的 skill，自动拉取最新版本。
.PARAMETER Org
    可选，只更新指定 GitHub 组织的 skill。
.PARAMETER Force
    强制覆盖本地修改（git reset --hard + pull），默认不覆盖。
.EXAMPLE
    .\update.ps1
    .\update.ps1 -Org SIE-Operations-and-Maintenance-Team
    .\update.ps1 -Force
#>

param(
    [string]$Org = "",
    [switch]$Force
)

$skillsDir = "$env:USERPROFILE\.claude\skills"
if (-not (Test-Path $skillsDir)) {
    Write-Host "❌ 未找到 skills 目录: $skillsDir" -ForegroundColor Red
    exit 1
}

$updated = 0
$skipped = 0
$errors = @()

Write-Host "=== SIE SMOM Skills 更新工具 ===" -ForegroundColor Cyan
Write-Host "扫描目录: $skillsDir`n" -ForegroundColor Gray

Get-ChildItem $skillsDir -Directory | ForEach-Object {
    $skillDir = $_.FullName
    $skillName = $_.Name
    $gitDir = Join-Path $skillDir ".git"

    if (-not (Test-Path $gitDir)) {
        return
    }

    Push-Location $skillDir
    $remoteUrl = git remote get-url origin 2>$null
    Pop-Location

    if (-not $remoteUrl) {
        return
    }

    if ($Org -and $remoteUrl -notmatch $Org) {
        return
    }

    Write-Host "  [$skillName]" -ForegroundColor Yellow

    Push-Location $skillDir

    $status = git status --porcelain 2>$null
    if ($status -and -not $Force) {
        Write-Host "    ⚠️  有本地修改，跳过（用 -Force 会覆盖）" -ForegroundColor DarkYellow
        $skipped++
        Pop-Location
        return
    }

    if ($Force -and $status) {
        Write-Host "    ⚠️  发现本地修改，执行 git reset --hard ..." -ForegroundColor DarkYellow
        git reset --hard HEAD 2>$null
    }

    $result = git pull --ff-only 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($result -match "Already up to date" -or $result -match "已经是最新的") {
            Write-Host "    ✅ 已是最新" -ForegroundColor Green
        } else {
            Write-Host "    ✅ 已更新" -ForegroundColor Green
            $updated++
        }
    } else {
        Write-Host "    ❌ 更新失败: $result" -ForegroundColor Red
        $errors += "$skillName : $result"
    }

    Pop-Location
}

Write-Host "`n=== 完成 ===" -ForegroundColor Cyan
Write-Host "已更新: $updated | 已跳过(有本地修改): $skipped | 失败: $($errors.Count)"
if ($errors.Count -gt 0) {
    Write-Host "`n失败详情:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}