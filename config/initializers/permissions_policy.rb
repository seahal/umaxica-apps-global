# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/host_origin_env").to_s

# Define an application-wide HTTP Permissions-Policy header.
# See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy

# WebAuthn directives are not yet supported by Rails' PermissionsPolicy out of the box.
# We extend it here to allow configuring these directives.
ActionDispatch::PermissionsPolicy.class_eval do
  define_method(:publickey_credentials_get) do |*sources|
    @directives["publickey-credentials-get"] = apply_mappings(sources)
  end

  define_method(:publickey_credentials_create) do |*sources|
    @directives["publickey-credentials-create"] = apply_mappings(sources)
  end
end

Rails.application.config.permissions_policy do |f|
  f.accelerometer(:none)
  f.camera(:none)
  f.geolocation(:none)
  f.gyroscope(:none)
  f.magnetometer(:none)
  f.microphone(:none)
  f.midi(:none)
  f.usb(:none)
  f.fullscreen(:self)
  f.payment(:none)

  # Allow WebAuthn for our authentication domains
  id_origins =
    HostOriginEnv.trusted_origins(
      ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
      ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    )

  f.publickey_credentials_get(:self, *id_origins)
  f.publickey_credentials_create(:self, *id_origins)
end
