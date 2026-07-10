# Auth Ceremony Grill — OPEN QUESTIONS

repo が答えられる事実は除外し、ユーザーの **value judgment / intent / trade-off / final authority**
のみを列挙する。1問ずつ確定していく。状態: `OPEN` / `DECIDED` / `DEFERRED` / `NOT-APPLICABLE`。

| Q-ID  | P   | Track        | 問い                                                                                                                                                | 現行 behavior              | 状態               |
| ----- | --- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ------------------ |
| GQ-01 | P0  | Social/Email | email 一致の social identity を既存 local account に link するか（pre-account-takeover の核心）。現状 link しない＝同一 email でも別 account になる | link しない（fail-closed） | **OPEN（質問中）** |
| GQ-02 | P1  | Email        | 新規 email の trust cooldown を採用するか。期間と surface 差                                                                                        | 実装無し                   | OPEN               |
| GQ-03 | P1  | X            | Turnstile token の hostname/action binding と single-use(replay) をローカル強制するか                                                               | ローカル強制する           | CLOSED / ACCEPTED  |
| GQ-04 | P1  | X            | TOTP same-window replay（FINDING-06）を lock で塞ぐか risk 受容か                                                                                   | 未修正                     | OPEN               |
| GQ-05 | P1  | X            | sign token controllers の CSRF `null_session` を許容（文書化）するか復元するか                                                                      | null_session               | OPEN               |
| GQ-06 | P1  | Telephone    | app/com で電話 OTP 単独で AAL1 を成立させるか、必ず追加 verifier を要すか                                                                           | org は追加要               | OPEN               |
| GQ-07 | P1  | X            | AS の実装現在地（acme vs sign.\*）の矛盾解消方針                                                                                                    | 矛盾あり                   | OPEN               |

補足:

- `X-039` / `X-040` は `GQ-03` の実装で CLOSED / ACCEPTED として扱う。
