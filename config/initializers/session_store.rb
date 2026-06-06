# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/jit_id_host_env").to_s
require Rails.root.join("lib/jit_session_cookie_config").to_s

# config/initializers/session_store.rb
force_secure = JitSessionCookieConfig.force_secure?(
  id_service_host: JitIdHostEnv.service_url.to_s,
)

Rails.application.config.session_store(
  :cookie_store,
  expire_after: 14.days,
  key: JitSessionCookieConfig.cookie_key(force_secure: force_secure),
  secure: force_secure,
  httponly: true,
  same_site: :lax,
  partitioned: JitSessionCookieConfig.partitioned?,
)
