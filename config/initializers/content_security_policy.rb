# typed: false
# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  boot_config = Rails.configuration.x.boot_config
  config.content_security_policy do |policy|
    # OriginValue#to_s already returns a scheme-prefixed origin (e.g. "https://www.umaxica.app").
    # Do not prepend "https://" again -- doing so produces a malformed allowlist entry like
    # "https://https://www.umaxica.app" which silently breaks form-action enforcement.
    acme_form_hosts =
      [
        boot_config.fetch(:hosts).acme_service.to_s,
        boot_config.fetch(:hosts).acme_corporate.to_s,
        boot_config.fetch(:hosts).acme_staff.to_s,
      ]
    sign_form_hosts =
      [
        boot_config.fetch(:hosts).sign_service.to_s,
        boot_config.fetch(:hosts).sign_corporate.to_s,
        boot_config.fetch(:hosts).sign_staff.to_s,
      ].uniq
    # The jump gateway is the first-party redirect broker that validates signed `rt`
    # tokens. Sign-flow form submissions (e.g. the sign-up birthdate checkpoint) finalize
    # by redirecting cross-host through it. Without this origin, `form-action` blocks that
    # redirect and the form navigation silently stalls on the submitting page.
    jump_form_hosts = [boot_config.fetch(:jump).origin.to_s]

    policy.default_src(:self)
    policy.base_uri(:self)
    policy.connect_src(:self, :https, :ws, :wss)
    # Allow @vite/client to hot reload changes in development
#    policy.connect_src *policy.connect_src, "ws://#{ ViteRuby.config.host_with_port }" if Rails.env.development?

    policy.font_src(:self, :https, :data)
    policy.form_action(
      :self,
      "https://accounts.google.com",
      "https://appleid.apple.com",
      *acme_form_hosts,
      *sign_form_hosts,
      *jump_form_hosts,
    )
    policy.frame_ancestors(:self)
    policy.frame_src(:self, "https://challenges.cloudflare.com")
    policy.img_src(:self, :https, :data)
    policy.manifest_src(:self)
    policy.object_src(:none)
    policy.script_src(:self, "https://challenges.cloudflare.com")
    # Allow @vite/client to hot reload javascript changes in development
#    policy.script_src *policy.script_src, :unsafe_eval, "http://#{ ViteRuby.config.host_with_port }" if Rails.env.development?

    # You may need to enable this in production as well depending on your setup.
#    policy.script_src *policy.script_src, :blob if Rails.env.test?

    policy.script_src_elem(:self, "https://challenges.cloudflare.com", "https://static.cloudflareinsights.com")
    policy.style_src(:self, :https)
    # Allow @vite/client to hot reload style changes in development
#    policy.style_src *policy.style_src, :unsafe_inline if Rails.env.development?

    policy.style_src_elem(:self, :https)
    policy.worker_src(:none)

    # Wire violation reports to the existing same-origin endpoint (one per surface).
    # The path is a fixed external contract (browsers cache report-uri); do not rename.
    # Endpoint: resource :csp_violation_report, path: "csp-violation-report" (see config/routes/*).
    policy.report_uri("/csp-violation-report")
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src script-src-elem style-src style-src-elem)
  config.content_security_policy_report_only = false
end
