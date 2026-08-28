<#
.SYNOPSIS
  GitHub Projects (v2) に、Backlog風の課題管理に必要なカスタムフィールドを構築する。

.DESCRIPTION
  自動化できる範囲:
    - Project の作成 (または既存 Project の再利用)
    - リポジトリとの紐付け (-Repo 指定時)
    - カスタムフィールド作成: Priority / Start date / Target date / Estimate

  自動化できない範囲 (GitHub の GraphQL API が未対応のため、手動で行う):
    - Table / Board / Roadmap の各ビュー作成
    - Status フィールドへの選択肢追加 (Backlog, Review など)
    - Iteration フィールドの作成 (gh CLI が ITERATION データ型の作成に未対応)
  このスクリプトの最後にチェックリストとして案内する。

.PARAMETER Owner
  Project のオーナー。個人アカウントなら "@me"、Organization ならその名前。

.PARAMETER Title
  作成する Project のタイトル。

.PARAMETER Repo
  Project を紐付けるリポジトリ ("owner/repo" 形式)。省略可。

.EXAMPLE
  .\setup.ps1 -Owner "@me" -Title "gh-project-kit" -Repo "toaruR/gh-project-kit"
#>

param(
    [string]$Owner = "@me",
    [string]$Title = "gh-project-kit",
    [string]$Repo = ""
)

$ErrorActionPreference = "Stop"

function Assert-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "gh CLI が見つかりません。先に GitHub CLI をインストールしてください。"
    }
    $status = gh auth status 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "gh にログインしていません。`gh auth login` を実行してください。"
    }
    if ($status -notmatch "project") {
        throw "認証トークンに 'project' スコープがありません。`gh auth refresh -s project` を実行してください。"
    }
}

function Get-OrCreate-Project {
    param([string]$Owner, [string]$Title)

    $existingJson = gh project list --owner $Owner --format json --limit 100 | ConvertFrom-Json
    $existing = $existingJson.projects | Where-Object { $_.title -eq $Title }
    if ($existing) {
        Write-Host "既存の Project '$Title' (#$($existing.number)) を再利用します。"
        return $existing
    }

    Write-Host "Project '$Title' を作成します。"
    $created = gh project create --owner $Owner --title $Title --format json | ConvertFrom-Json
    return $created
}

function Ensure-Field {
    param(
        [string]$Owner,
        [int]$Number,
        [string]$Name,
        [string]$DataType,
        [string[]]$Options = @()
    )

    $fields = gh project field-list $Number --owner $Owner --format json --limit 100 | ConvertFrom-Json
    if ($fields.fields | Where-Object { $_.name -eq $Name }) {
        Write-Host "  - フィールド '$Name' は既に存在します。スキップします。"
        return
    }

    Write-Host "  - フィールド '$Name' ($DataType) を作成します。"
    if ($Options.Count -gt 0) {
        gh project field-create $Number --owner $Owner --name $Name --data-type $DataType --single-select-options ($Options -join ",") | Out-Null
    }
    else {
        gh project field-create $Number --owner $Owner --name $Name --data-type $DataType | Out-Null
    }
}

Assert-Gh

$project = Get-OrCreate-Project -Owner $Owner -Title $Title
$projectNumber = $project.number

if ($Repo -ne "") {
    Write-Host "リポジトリ '$Repo' を Project #$projectNumber に紐付けます。"
    gh project link $projectNumber --owner $Owner --repo $Repo | Out-Null
}

Write-Host "カスタムフィールドを構築します。"
Ensure-Field -Owner $Owner -Number $projectNumber -Name "Priority"    -DataType "SINGLE_SELECT" -Options @("🔴 High", "🟡 Medium", "🟢 Low")
Ensure-Field -Owner $Owner -Number $projectNumber -Name "Start date"  -DataType "DATE"
Ensure-Field -Owner $Owner -Number $projectNumber -Name "Target date" -DataType "DATE"
Ensure-Field -Owner $Owner -Number $projectNumber -Name "Estimate"    -DataType "NUMBER"

$projectUrl = (gh project view $projectNumber --owner $Owner --format json | ConvertFrom-Json).url

Write-Host ""
Write-Host "=== 自動構築ここまで ===" -ForegroundColor Green
Write-Host "Project URL: $projectUrl"
Write-Host ""
Write-Host "=== 以下は手動で行ってください (API未対応のため) ===" -ForegroundColor Yellow
Write-Host "1. $projectUrl を開く"
Write-Host "2. 左上の '+ New view' から以下の3つを作成する"
Write-Host "     - 課題一覧: Layout = Table"
Write-Host "     - ボード:   Layout = Board, Group by = Status"
Write-Host "     - ガント:   Layout = Roadmap, Start date = 'Start date', Target date = 'Target date'"
Write-Host "3. 既定の 'Status' フィールドに 'Backlog' と 'Review' の選択肢を追加する"
Write-Host "     (Project 右上の ... > Settings > Status フィールドを編集)"
Write-Host "4. 必要であれば 'Iteration' フィールドを追加する"
Write-Host "     (+ New field > Iteration。CLIは ITERATION 型の作成に未対応)"
Write-Host ""
Write-Host "課題を一括投入するには .\.github\project\seed-issues.ps1 を使ってください。"
