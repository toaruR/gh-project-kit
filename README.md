# gh-project-kit

Backlog の「課題一覧 / ボード / ガントチャート」を GitHub Issues + Projects (v2) 上に構築するためのキット。
Project の設定・Issue登録を `gh` CLI でコード化し、再現可能にする。

## 構成

```
.github/
├── ISSUE_TEMPLATE/
│   ├── config.yml      # 白紙Issue作成を禁止
│   ├── feature.yml      # 目的 / 要件 / 完了条件
│   └── bug.yml           # 現在の挙動 / 期待する挙動 / 再現手順 / 完了条件
└── project/
    ├── setup.ps1              # Project作成 + カスタムフィールド構築
    ├── seed-issues.ps1        # タスク一覧からIssue一括作成 + Project登録
    └── tasks.example.json     # 投入サンプル
```

## 前提

- [GitHub CLI](https://cli.github.com/) がインストール済み
- `gh auth login` 済みで、`project` スコープを保持していること
  ```bash
  gh auth refresh -s project
  ```

## 使い方

### 1. Project とカスタムフィールドを構築する

```powershell
.\.github\project\setup.ps1 -Owner "@me" -Title "gh-project-kit" -Repo "toaruR/gh-project-kit"
```

自動的に作られるもの:

| 項目 | 内容 |
|---|---|
| Project | 指定タイトルで作成 (既存があれば再利用) |
| Priority | Single select: 🔴 High / 🟡 Medium / 🟢 Low |
| Start date | Date |
| Target date | Date |
| Estimate | Number |

### 2. 手動で行うこと(API未対応のため)

GitHub の Projects v2 は、**ビューの新規作成と、既存 Status フィールドへの選択肢追加が GraphQL API に存在しない**(2026年8月時点、GitHub公式にも同様の要望が上がっている既知の制限)。そのため以下は手動で行う。`setup.ps1` の実行後に手順が表示される。

1. Project を開き、`+ New view` から3ビューを作成する
   - **課題一覧**: Layout = Table
   - **ボード**: Layout = Board, Group by = `Status`
   - **ガント**: Layout = Roadmap, Start field = `Start date`, Target field = `Target date`
2. 既定の `Status` フィールドに `Backlog` と `Review` の選択肢を追加する(Project設定 > Status を編集)
3. 必要なら `Iteration` フィールドを追加する(`gh` CLI は ITERATION 型の作成に未対応)

### 3. タスクを一括投入する

`tasks.example.json` を編集するか複製して、実際のタスク一覧を用意する。

```json
{
  "title": "ログイン画面を作る",
  "body": "## 目的\n...",
  "labels": ["enhancement"],
  "priority": "🔴 High",
  "start": "2026-09-01",
  "target": "2026-09-05",
  "estimate": 5
}
```

```powershell
.\.github\project\seed-issues.ps1 -Owner "@me" -ProjectNumber 1 -Repo "toaruR/gh-project-kit" -TasksFile ".\.github\project\tasks.example.json"
```

各タスクについて、実際の GitHub Issue を作成 → Project へ登録 → Priority / Start date / Target date / Estimate を設定する。

## Backlog との違い

| 機能 | GitHub Projects | Backlog |
|---|---|---|
| 課題管理 | ◎ | ◎ |
| カンバン | ◎ | ◎ |
| ガント | ○ (依存関係・工数の自動計算はなし) | ◎ |
| Git/PR連携 | ◎◎ | ○ |
| AIエージェントとの相性 | ◎◎ (Issue → Agent → Branch → PR → Merge がひと続き) | △ |
| Wiki | ○ | ◎ |
| 非エンジニア向け | ○ | ◎ |

ソフトウェア開発のタスク管理に絞るなら、GitHub 側にかなり寄せられる。特に Issue を Codex CLI / Claude Code / Antigravity CLI のようなAIエージェントへの作業指示として使う運用とは相性が良い。

## AIエージェント連携の拡張案

Issue本文に「目的 / 要件 / 完了条件」を書く(`feature.yml` テンプレートが強制する)ことで、Issueをそのままエージェントへの作業指示として使える。

```
Backlog登録 → Issue作成 → AIエージェントが着手 → Branch → PR → Review → Merge → Status=Done
```

`Status` が `Done` になったら Project 側で完了を追うだけで良い状態を目指す。
