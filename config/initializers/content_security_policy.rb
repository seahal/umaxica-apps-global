# typed: false
# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    acme_form_hosts =
      [
        ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
        ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
        ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      ].map { |host| "https://#{host}" }
    sign_form_hosts =
      %w(
        ID_SERVICE_URL
        SIGN_SERVICE_URL
        ID_CORPORATE_URL
        SIGN_CORPORATE_URL
        ID_STAFF_URL
        SIGN_STAFF_URL
      ).filter_map { |key| ENV[key].presence }.uniq.map { |host| "https://#{host}" }

    policy.default_src(:self)
    policy.base_uri(:self)
    policy.connect_src(:self, :https)
    policy.font_src(:self, :https, :data)
    policy.form_action(
      :self,
      "https://accounts.google.com",
      "https://appleid.apple.com",
      *acme_form_hosts,
      *sign_form_hosts,
    )
    policy.frame_ancestors(:self)
    policy.frame_src(:self, "https://challenges.cloudflare.com")
    policy.img_src(:self, :https, :data)
    policy.manifest_src(:self)
    policy.object_src(:none)
    policy.script_src(:self, "https://challenges.cloudflare.com")
    policy.script_src_elem(:self, "https://challenges.cloudflare.com", "https://static.cloudflareinsights.com")
    policy.style_src(:self, :https)
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
