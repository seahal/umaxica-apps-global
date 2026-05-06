# Ongoing Rails Engine Migration State (2026-04-20)

> **Status update (2026-04-26):** Obsolete. Beyond the existing abandonment noted below, per
> `adr/split-into-regional-and-global-repos.md` (2026-04-25) the Rails Engine and 4-app strategies
> are both permanently retired. The codebase is now divided into two independent repositories: this
> **global** repository (a single ordinary Rails app combining IdP and RP, served on `id.*` and
> `www.*`) and a separate **regional** repository (docs / news / help). Do not resume the migration
> steps described below.

## Status

Abandoned (2026-04-22). Direction changed by `adr/rails-way-engine-architecture-restoration.md`.

> **Abandonment notice (2026-04-22):** The wrapper apps migration described below is no longer the
> project direction. The repository returns to the Rails Way (single host Rails app + four mountable
> Fat Engines + native engine routing proxies). Do not resume the steps in this document. A fresh
> implementation plan will be authored separately. This file is retained for historical traceability
> only.

## Context

(Historical) Root アプリケーションから 4 つの独立した Rails アプリケーション (`Identity`, `Zenith`,
`Foundation`, `Distributor`) への移行作業中でした。この方向性は 2026-04-22 に放棄されました。

## 完了した作業

- **ラッパーアプリ (`apps/`)**:
  - `identity`, `zenith`, `foundation`, `distributor` のスケルトン作成。
  - 各アプリの `config/boot.rb` でルートの `lib/` を `LOAD_PATH` に追加。
  - 各アプリの `config/application.rb` で `lib/` およびルートの `app/errors`, `app/controllers`
    をオートロード対象に設定（移行期間用）。
  - 各アプリの `routes.rb` ですべてのエンジンをマウント（互換性確保のため）。
- **エンジンのフラット化**:
  - `engines/*/app/controllers/` 等の `jit/<engine_name>/` による冗長なネストを削除。
  - `engine.rb` にて `Zeitwerk` マッピングを修正し、`Jit::<Engine>` 名前空間を維持。
  - ビューパスの優先順位を `prepend_view_path` で調整。
- **コード移動**:
  - `app/models`, `app/services`, `app/helpers`, `app/controllers/concerns`, `app/jobs`,
    `app/mailers`, `app/policies`, `app/subscribers`, `app/validators`, `app/assets`,
    `app/javascript`, `app/config` 内のファイルを各エンジンまたは `lib/` へ移動。
  - `test/` 内の対応するテストファイルおよびフィクスチャを各エンジンまたは `lib/` へ移動。
  - 共有ベースクラス (`ApplicationRecord`, `Current`, `ApplicationController` 等) を `lib/` へ移動。
- **構成修正**:
  - `database.yml` の `migrations_paths` をルートの `db/` を指すように修正。
  - マイグレーションファイル内の `Rails.root.join("lib/...")` を `File.expand_path` に一括置換。
  - `Jit::Deployment` および `DEPLOY_MODE` 関連のコードとテストを削除。

## 現在の問題と未完了タスク

- **Identity テストの失敗**:
  - `UrlGenerationError`: 統合テストにおいて、一部のルートヘルパーがフラット化後のコントローラーを正しく参照できていない。
  - `ActiveRecord::RecordInvalid`: `settings_preferences`
    等のフィクスチャが、最新のデータベース制約（ポリモーフィック owner の廃止）に適合していない。
- **残りのラッパーアプリの整備**:
  - `zenith`, `foundation`, `distributor` については、まだ `db:prepare`
    や個別テストの動作確認が行われていない。
- **クリーンアップ**:
  - ルートに残っている `bin/`, `Rakefile`, `Procfile.dev` 等の整理。

## 再開時の手順

1. `apps/identity` で残っている `UrlGenerationError` を解決する（`engines/identity/config/routes.rb`
   の名前空間指定と実際のコントローラーパスの整合性を確認）。
2. `engines/identity/test/fixtures/` 内のフィクスチャを最新のスキーマに合わせて修正する。
3. 他の 3 つのアプリについても順次 `db:prepare` を実行し、テストが通ることを確認する。
4. すべてのアプリでテストが安定したら、ルートの不要なディレクトリを完全に削除する。
