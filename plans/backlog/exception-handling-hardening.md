# Exception Handling Hardening Plan

## Problem

このリポジトリでは、想定外の例外まで広く捕まえる `rescue StandardError`
や同等のキャッチが多い。結果として、本来は 5xx で表面化すべき不具合が握りつぶされ、原因追跡と修正が遅くなっている。

## Goal

- 予期しない例外は原則として握りつぶさず、5xx として露出させる。
- 想定内の分岐だけを個別例外で処理する。
- 「失敗を隠す rescue」を減らし、障害検知しやすくする。

## Proposed Steps

1. `rescue StandardError` と `rescue nil` を棚卸しする。
2. 例外ごとに、想定内の分岐だけを残して、それ以外は再送出する。
3. コントローラは HTTP 層の責務に限定し、サービス層の失敗は明示的な例外か結果オブジェクトで返す。
4. 5xx になるべきケースを統合テストで確認する。

## Scope Notes

- DBSC / preference / auth / token / social login などの領域を横断して見直す。
- ただし、外部API不調や入力不正など「業務上の失敗」は個別 rescue を許容する。
- 目的は例外ゼロではなく、不要な隠蔽をやめること。

## Verification

- `rescue StandardError` の削減前後で、失敗時の HTTP ステータスが変わらないか確認する。
- 期待外の例外が 500 系で返るテストを、重要な public / sign ルートに追加する。
- 既存のログ出力や監視アラートがあるなら、例外が握りつぶされなくなることも確認する。
