# 死んだ `X-TEST-CURRENT-*` ヘッダーへの依存を、実JWT認証へ移行する

## Context（なぜこの変更をするか）

`bin/rails test` の残り失敗(~840件規模)のうち最大の構造的要因として、約280件のテストファイルが
`X-TEST-CURRENT-RESOURCE` / `X-TEST-CURRENT-USER` / `X-TEST-CURRENT-STAFF` / `X-TEST-CURRENT-VIEWER`
という HTTP ヘッダーで認証を偽装しようとしているが、**このヘッダーを読むコードは `app/` `lib/`
のどこにも存在しない**ことを前回確認した。

このバイパス機構は過去に意図的に削除され、`test/unit/security/app_test_bypass_guard_test.rb` と
`test/unit/security/forbidden_rails_patterns_test.rb`
が「二度と復活させない」ことを明示的にガードしている（コメント: "A test-only verification bypass was
previously removed; this pins it
shut."）。よって、このヘッダーを app 側で再び読めるようにする選択肢は無い。残された道は、
**テスト側を実際の認証方式（JWT）に合わせて直す**こと。

2つの調査エージェントによる事実確認:

- 約280〜282ファイルがこのヘッダー群を計2,212箇所で使用（内訳: USER 756 / STAFF 731 / RESOURCE
  723）。テストファイル全体(~1,278件)の約22%。
- これらのファイルのヘッダー組み立てヘルパー（`as_user_headers` / `as_staff_headers` /
  `as_visitor_headers` という DAMP ローカル複製、代表例は
  `test/controllers/auth/app/dashboards_controller_test.rb:84-99`）は、死んだヘッダーを足す
  **と同時に**
  実トークン（`ClientToken`/`OperatorToken`/`VisitorToken`）も作成しているが、その実トークンを
  **JWT として `Authorization` ヘッダーや access
  cookie に載せていない**。つまりこれらのテストは「認証できたつもり」になっているだけで、実際には未認証のままリクエストを送っている。
- 影響ファイルの大半（368件規模）は `ActionDispatch::IntegrationTest`
  （Rack ミドルウェアを通る完全な HTTP リクエスト）であり、`current_resource`
  はミドルウェア内（`AuthenticationBase#load_from_token`）で解決されるため、コントローラのメソッドを
  `define_singleton_method`
  で直接スタブする軽量な代替は使えない。9ファイルのみそのスタブ方式を使っているが、いずれも非統合（ユニット）テストでHTTPを実際には叩いていない。
- **既に動いている正しい代替パターンがコードベース内に266ファイル分存在する**（`Authorization: Bearer <jwt>`
  ヘッダーを使うもの）。ただし98%(261件)がなぜか死んだヘッダーと併用されている＝ 一部移行が中途半端に進んでいた形跡。完全にBearerのみで動いているのは5ファイル（すべてユニットテスト）。

結論: **軽量な近道は無い。**
約280ファイルそれぞれで、死んだヘッダーに加えて（あるいは代えて）本物の JWT を
`Authorization: Bearer`
として送るよう、ローカルヘルパーを拡張する必要がある。これは機械的だが大規模な移行であり、1ターンで一括完了させるのではなく、検証可能な単位で段階的に進める。

## 確立済みの正しいパターン（これに統一する）

`test/controllers/auth/app/in/emails_controller_test.rb`
等、複数ファイルに既に存在するDAMP ローカルヘルパーの組み合わせを正とする:

```ruby
def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil,
                         resource_type: nil, dpop_jkt: nil)
  host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
  resource_type ||=
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    end
  AuthenticationToken.encode(
    resource,
    host: host_value,
    session_id: session_id,
    session_public_id: session_public_id,
    resource_type: resource_type,
    dpop_jkt: dpop_jkt,
    jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
  )
end

def jwt_issuer_id_for_test_host(host, resource_type)
  normalized = host.to_s
  service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
  surface =
    if service == "SIGN"
      case resource_type
      when "operator" then "ORG"
      when "visitor" then "COM"
      else "APP"
      end
    elsif normalized.include?(".org") || normalized.include?("org.")
      "ORG"
    elsif normalized.include?(".com") || normalized.include?("com.")
      "COM"
    else
      "APP"
    end
  "surface:#{service}_#{surface}"
end

def bearer_headers(token, host: nil, headers: {})
  host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
end
```

各ファイルの `as_user_headers`(他 `as_staff_headers`/`as_visitor_headers`) を、死んだ
`X-TEST-CURRENT-*` を足す代わりに（または足しつつ、無害なので残してもよい）、上記で作ったトークンを
`Authorization: Bearer` として **実際に** 載せるよう拡張する。例:

```ruby
def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
  ensure_user_token_reference_records!
  token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
  token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
  token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

  bearer_headers(
    jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client"),
    host: host,
    headers: headers,
  )
end
```

ファイルごとに既存の `as_*_headers`
の実装が微妙に異なる（DAMP）ため、機械的な一括置換ではなく、**各ファイルを読んで実装に合わせて拡張**する。`jwt_access_token_for`/
`jwt_issuer_id_for_test_host`/`bearer_headers`
が既にそのファイルに定義済みならそれを使い、無ければ上記を DAMP コピーする。

## 進め方（段階的・検証可能な単位で）

一括280ファイルを1パスで変更すると、後述の「認証以外の既存バグ」（前回 Cluster
3 で見た apple_social_flows_test.rb のような無関係な事前バグ）が大量に混ざり込み、切り分けが困難になる。よって以下の順で進める:

1. **パイロット（1ディレクトリ）**: `test/controllers/auth/org/`
   配下（調査で最多14件、関連ディレクトリ含め~24件）を最初のバッチとして移行し、パターンが実際に失敗を解消するか・新たな回帰を生まないかを確認する。
2. パイロットの結果を見て、ファイルごとに：
   - 認証エラー由来の失敗が解消したか（403/401/302未認証リダイレクト等が消えるか）
   - 認証以外の理由で残る失敗があれば、その場で直す範囲か(明らかなtypo/route名のずれ等)、それとも別タスクとして記録するか(深い仕様不整合)を都度判断する。Cluster
     2/3で確立したルール: 「テスト全体を壊す/別ファイルの矛盾する期待を壊すリスクがある変更は単体検証してから入れる」を踏襲する。
3. パイロットが安定したら、残りのディレクトリを件数の多い順（test/integration
   40件、test/controllers/base/app 13件、…）に同様の手順でバッチ処理する。
4. 各バッチ後に該当ファイル群だけを実行して確認し、数バッチごとにフルスイートを走らせて合計失敗数の減少とガードテスト（`app_test_bypass_guard_test.rb`,
   `forbidden_rails_patterns_test.rb`）が引き続きパスすることを確認する。

各バッチの作業はユーザーの追加承認を待たずに連続して進める（既に「1をやって」と承認済み）。ただし、ある段階で「個別ファイルの修正方針に複数の妥当な選択肢がある」「既存テストの意図そのものが曖昧/矛盾している」など、Cluster
2 で遭遇したような判断が必要な事態に当たった場合は、そこで一旦立ち止まりユーザーに確認する。

## 注意点・既存ルールの再確認

- `app/` `lib/` には一切手を入れない（今回はテスト側のみの変更）。
- 各ファイルのローカルヘルパーへの追記は DAMP 方針に従い、別ファイルからの `require`
  や共有モジュール化はしない（前回ユーザーから明示された方針）。
- 死んだ `X-TEST-CURRENT-*`
  ヘッダー自体を削除するかどうかは任意（無害なので残してもよい）。削除する場合は、そのファイルの可読性向上のためであり、必須ではない。
- 認証が直らないと到達できない箇所で別の既存バグが見つかった場合、Cluster
  3 と同じ基準（独立して検証可能・小さい・他のテストを壊さない）を満たすものだけその場で直し、それ以外は記録だけして次に回す。

## 検証

- パイロット後: `bin/rails test test/controllers/auth/org/`
  を実行し、認証由来の失敗（401/403/302リダイレクト系）が解消することを確認。
- バッチ追加ごとに対象ファイルを実行。
- 数バッチごとにフルスイート `bin/rails test`
  を実行し、合計失敗数のトレンドとガードテスト（`app_test_bypass_guard_test.rb`,
  `forbidden_rails_patterns_test.rb`）の pass を確認。
- 最終的に全280ファイル分のバッチが終わった時点でフルスイートを実行し、「死んだヘッダー由来の失敗」がどれだけ解消したか、残る失敗が別カテゴリ（Cluster
  1 残り・Cluster 2 未決・個別の既存バグ）に分類できるかを報告する。
