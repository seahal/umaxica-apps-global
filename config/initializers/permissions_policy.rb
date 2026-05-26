# typed: false
# frozen_string_literal: true

# Define an application-wide HTTP Permissions-Policy header.
# See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy

# WebAuthn directives are not yet supported by Rails' PermissionsPolicy out of the box.
# We extend it here to allow configuring these directives.
ActionDispatch::PermissionsPolicy.class_eval do
  define_method(:publickey_credentials_get) do |*sources|
    @directives["publickey-credentials-get"] = apply_mappings(sources)
  end
end

Rails.application.config.permissions_policy do |f|
  f.accelerometer(:none)
  f.bluetooth(:none) if f.respond_to?(:bluetooth)
  f.camera(:none)
  f.geolocation(:none)
  f.gyroscope(:none)
  f.magnetometer(:none)
  f.microphone(:none)
  f.midi(:none)
  f.serial(:none) if f.respond_to?(:serial)
  f.usb(:none)
  f.payment(:none)

  f.publickey_credentials_get(:self)
end
