# typed: false
# frozen_string_literal: true

# Define an application-wide HTTP Permissions-Policy header.
# See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy

permissions_policy_header = [
  "accelerometer=()",
  "camera=()",
  "geolocation=()",
  "gyroscope=()",
  "magnetometer=()",
  "microphone=()",
  "midi=()",
  "payment=()",
  "publickey-credentials-get=(self)",
  "serial=()",
  "usb=()",
].join(",")

Rails.application.config.action_dispatch.default_headers.merge!(
  "Cross-Origin-Embedder-Policy" => "credentialless",
  "Cross-Origin-Opener-Policy" => "same-origin",
  "Cross-Origin-Resource-Policy" => "same-origin",
  "Permissions-Policy" => permissions_policy_header,
)
