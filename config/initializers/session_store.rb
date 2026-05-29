# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/jit/id_host_env").to_s
require Rails.root.join("lib/jit/session_cookie_config").to_s

# config/initializers/session_store.rb
force_secure = Jit::SessionCookieConfig.force_secure?(
  id_service_host: Jit::IdHostEnv.service_url.to_s,
)

Rails.application.config.session_store(
  :cookie_store,
  expire_after: 14.days,
  key: Jit::SessionCookieConfig.cookie_key(force_secure: force_secure),
  secure: force_secure,
  httponly: true,
  same_site: :lax,
  partitioned: Jit::SessionCookieConfig.partitioned?,
)
