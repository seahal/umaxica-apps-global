# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/id_host_env").to_s
require Rails.root.join("lib/session_cookie_config").to_s

# config/initializers/session_store.rb
force_secure = SessionCookieConfig.force_secure?(
  id_service_host: IdHostEnv.service_url.to_s,
)

Rails.application.config.session_store(
  :cookie_store,
  expire_after: 14.days,
  key: SessionCookieConfig.cookie_key(force_secure: force_secure),
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
)
