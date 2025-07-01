#!/usr/bin/env bash
slug=$(date +%Y%m%d_%H%M)_$1.md
cat <<EOF > record/$slug
# $1

**症状**

**推测**

**实验**

**根因 & 改动**

**复盘**
EOF
git add record/$slug
code record/$slug        # 或 obsidian 打开
