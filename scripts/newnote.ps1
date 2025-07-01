param([string]$title)

if (-not $title) {
  Write-Error "需要标题，例如 ./newnote.ps1 fifo_underflow"
  exit 1
}

$slug = (Get-Date -Format "yyyyMMdd_HHmm") + "_$title.md"
$path = Join-Path "..\record" $slug

@"
# $title

**症状**

**推测**

**实验**

**根因 & 改动**

**复盘**
"@ | Out-File $path -Encoding utf8

git add $path
code $path        # 若想直接用 VS Code 打开
