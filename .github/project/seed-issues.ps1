<#
.SYNOPSIS
  JSON形式のタスク一覧から、GitHub Issue を一括作成し Project に登録する。

.DESCRIPTION
  各タスクについて以下を行う:
    1. gh issue create でリポジトリに実際の Issue を作成
    2. gh project item-add で Project に登録
    3. Priority / Start date / Target date / Estimate フィールドを設定
  事前に .\setup.ps1 で Project とカスタムフィールドを作成しておくこと。

.PARAMETER Owner
  Project のオーナー。個人アカウントなら "@me"。

.PARAMETER ProjectNumber
  対象 Project の番号 (setup.ps1 実行時の出力、または `gh project list` で確認)。

.PARAMETER Repo
  Issue を作成するリポジトリ ("owner/repo" 形式)。

.PARAMETER TasksFile
  タスク一覧の JSON ファイルパス。既定は同ディレクトリの tasks.example.json。

.EXAMPLE
  .\seed-issues.ps1 -Owner "@me" -ProjectNumber 1 -Repo "toaruR/gh-project-kit"
#>

param(
    [string]$Owner = "@me",
    [Parameter(Mandatory = $true)][int]$ProjectNumber,
    [Parameter(Mandatory = $true)][string]$Repo,
    [string]$TasksFile = (Join-Path $PSScriptRoot "tasks.example.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TasksFile)) {
    throw "タスクファイルが見つかりません: $TasksFile"
}

$tasks = Get-Content $TasksFile -Raw | ConvertFrom-Json

foreach ($task in $tasks) {
    Write-Host "Issue作成: $($task.title)"

    $ghArgs = @("issue", "create", "--repo", $Repo, "--title", $task.title, "--body", $task.body)
    if ($task.labels -and $task.labels.Count -gt 0) {
        $ghArgs += @("--label", ($task.labels -join ","))
    }

    $issueUrl = (& gh @ghArgs | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $issueUrl) {
        Write-Warning "  Issue作成に失敗しました: $($task.title)"
        continue
    }
    Write-Host "  -> $issueUrl"

    gh project item-add $ProjectNumber --owner $Owner --url $issueUrl | Out-Null

    if ($task.priority) {
        gh project item-edit $ProjectNumber --owner $Owner --url $issueUrl --field "Priority" --value $task.priority | Out-Null
    }
    if ($task.start) {
        gh project item-edit $ProjectNumber --owner $Owner --url $issueUrl --field "Start date" --date $task.start | Out-Null
    }
    if ($task.target) {
        gh project item-edit $ProjectNumber --owner $Owner --url $issueUrl --field "Target date" --date $task.target | Out-Null
    }
    if ($null -ne $task.estimate) {
        gh project item-edit $ProjectNumber --owner $Owner --url $issueUrl --field "Estimate" --number $task.estimate | Out-Null
    }
}

Write-Host ""
Write-Host "完了。Project を確認してください: gh project view $ProjectNumber --owner $Owner --web"
