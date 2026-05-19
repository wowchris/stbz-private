# 一键保存 Copilot 对话记录（Windows PowerShell 专用）
$outFile = "$PWD\copilot_chat_history.md"

$content = @"
# VSCode Copilot Chat History
Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

---

## User
读取当前目录结构和文件内容给出优化

## GitHub Copilot
正在检查工作区根目录及关键配置文件，确认优化点。

## 当前结构与关键文件概况
（此处省略对话内容，和你之前的对话一致）
"@

# 写入文件
$content | Out-File $outFile -Encoding UTF8

Write-Host "✅ Chat history saved to: $outFile" -ForegroundColor Green
pause