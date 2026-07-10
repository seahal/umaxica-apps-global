# Context

`gh auth login` をコンテナ内で実行すると `mkdir /home/global/.config/gh: permission denied`
で失敗する。ホスト側の `~/.config/gh` がコンテナにマウントされていないため、`gh`
CLI がクレデンシャルを書き込もうとして失敗している。

`devcontainer.json` の `mounts` にはすでに同じ `~/.config/`
配下のディレクトリが読み取り専用でマウントされているパターンがある（`~/.config/git`,
`~/.config/opencode`）。同じパターンで `~/.config/gh` を追加する。

# 変更

**ファイル:** `.devcontainer/devcontainer.json`

`mounts` 配列に 1 行追加:

```json
"source=${localEnv:HOME}/.config/gh,target=/home/global/.config/gh,type=bind,readonly"
```

既存の `~/.config/opencode` マウントの直後に挿入する（行 113 付近）。

# 前提条件

ホスト側に `~/.config/gh`
が存在し、有効なクレデンシャルが保存されていること。コンテナ内ではなくホスト側で `gh auth login`
を実行してから devcontainer を再ビルドする。

# 確認手順

1. devcontainer を再ビルド（VS Code: "Rebuild Container" /
   `devcontainer up --remove-existing-container`）
2. コンテナ内で `gh auth status` → `Logged in to github.com` が表示されること
3. `gh issue list` が正常に動作すること
