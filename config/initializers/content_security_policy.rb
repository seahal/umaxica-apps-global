# typed: false
# frozen_string_literal: true

require Rails.root.join("lib/host_origin_env").to_s

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  id_origins =
    HostOriginEnv.trusted_origins(
      ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
      ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    )
  apex_origins =
    HostOriginEnv.trusted_origins(
      ENV.fetch("APEX_SERVICE_URL", "www.app.localhost"),
      ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost"),
      ENV.fetch("APEX_STAFF_URL", "www.org.localhost"),
    )

  config.content_security_policy do |policy|
    policy.default_src(:self, :https)
    policy.font_src(:self, :https, :data)
    policy.img_src(:self, :https, :data)
    policy.object_src(:none)
    policy.script_src(:self, :https, "https://challenges.cloudflare.com", "https://static.cloudflareinsights.com")
    # Allow @vite/client to hot reload javascript changes in development
    #    policy.script_src *policy.script_src, :unsafe_eval,
    #                      "http://#{ ViteRuby.config.host_with_port }" if Rails.env.development?

    # You may need to enable this in production as well depending on your setup.
    #    policy.script_src *policy.script_src, :blob if Rails.env.test?

    policy.frame_src(:self, :https, "https://challenges.cloudflare.com")
    policy.style_src(:self, :https, :unsafe_inline) {
      # Allow @vite/client to hot reload style changes in development
      #    policy.style_src *policy.style_src, :unsafe_inline if Rails.env.development?

      # unsafe_inline is needed for some legacy styles but nonced by generator below
    }

    # Support for id.* and www.* subdomains
    policy.connect_src(
      # Allow @vite/client to hot reload changes in development
      #    policy.connect_src *policy.connect_src, "ws://#{ ViteRuby.config.host_with_port }" if Rails.env.development?
      :self,
      :https,
      "https://cloudflareinsights.com",
      *id_origins,
      *apex_origins,
    )

    # Report CSP violations to our logging endpoint
    policy.report_uri("/csp-violation-report")
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src style-src)

  # Automatically add `nonce` to `javascript_tag`, `javascript_include_tag`, and `stylesheet_link_tag`
  # if the corresponding directives are specified in `content_security_policy_nonce_directives`.
  config.content_security_policy_nonce_auto = true

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
