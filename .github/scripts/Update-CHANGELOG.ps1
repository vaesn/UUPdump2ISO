<#
.SYNOPSIS
    通用更新 CHANGELOG.md 脚本
.DESCRIPTION
    专为 GitHub Actions 设计。自动读取环境变量，生成格式化的更新日志，
    并以 UTF-8 BOM 编码写入文件，确保中文不乱码。
#>
param(
    [string]$Version,
    [string]$FileName
)

# --- 1. 参数获取 (优先使用传入参数，其次使用环境变量) ---
if (-not $Version) { $Version = $env:Build_VERSION }
if (-not $FileName) { $FileName = $env:FILE_NAME }

# --- 2. 环境变量检查 ---
if ([string]::IsNullOrWhiteSpace($Version) -or [string]::IsNullOrWhiteSpace($FileName)) {
    Write-Host "⚠️ Warning: Version 或 FileName 为空。跳过更新日志。"
    exit 0
}

if (-not $env:GITHUB_REPOSITORY) {
    Write-Host "⚠️ Warning: 未在 GitHub 环境中运行。"
    exit 0
}

# --- 3. 变量初始化 ---
$Date = Get-Date -Format "yyyy-MM-dd HH:mm"
$Tag = "${FileName}-${Version}"
$RepoUrl = "https://github.com/$($env:GITHUB_REPOSITORY)"
$ReleaseUrl = "${RepoUrl}/releases/tag/${Tag}"

# --- 4. 生成 Markdown 内容 ---
$NewEntry = @"
## [$Tag] - $Date

### 📦 资源信息

| 项目 | 链接 |
| :--- | :--- |
| **版本** | $Version |
| **下载** | [Release 页面 ($FileName)]($ReleaseUrl) |

---

"@

# --- 5. 文件操作 (带重试机制，防止并发冲突) ---
$ChangelogFile = "CHANGELOG.md"
$MaxRetries = 3
$RetryDelay = 2


# 预先计算绝对路径 (读取和写入都使用它)
$workspacePath = $env:GITHUB_WORKSPACE
if (-not $workspacePath) {
    $workspacePath = (Get-Location).Path
}
$fullPath = Join-Path $workspacePath $ChangelogFile

for ($i = 0; $i -lt $MaxRetries; $i++) {
    try {
        if (Test-Path $fullPath) {
            # 读取现有内容
            $OldContent = Get-Content $fullPath -Raw -Encoding UTF8
        } else {
            # 创建新文件头
            $OldContent = "# 📝 Windows Build History`n`n"
        }

        # 拼接内容
        if ($OldContent -notmatch "^\s*$") {
            $FinalContent = $NewEntry + "`n`n" + $OldContent
        } else {
            $FinalContent = $NewEntry + $OldContent
        }

        # 写入文件
        $Utf8BomEncoding = New-Object System.Text.UTF8Encoding $True
        [System.IO.File]::WriteAllText($fullPath, $FinalContent, $Utf8BomEncoding)
        
        Write-Host "✅ CHANGELOG updated successfully at $fullPath."
        break
    }
    catch {
        Write-Host "⚠️ Attempt $($i+1) failed: $($_.Exception.Message)"
        Start-Sleep -Seconds $RetryDelay
    }
}

if (-not $success) {
    Write-Error "❌ Failed to update CHANGELOG after $MaxRetries attempts."
    exit 1
}


