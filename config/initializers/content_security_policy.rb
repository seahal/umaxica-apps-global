# typed: false
# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src(:self)
    policy.base_uri(:self)
    policy.connect_src(:self, :https)
    policy.font_src(:self, :https, :data)
    policy.form_action(:self)
    policy.frame_ancestors(:self)
    policy.frame_src(:self, "https://challenges.cloudflare.com")
    policy.img_src(:self, :https, :data)
    policy.manifest_src(:self)
    policy.object_src(:none)
    policy.script_src(:self, "https://challenges.cloudflare.com")
    policy.style_src(:self, :https)
    policy.worker_src(:none)
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src)
  config.content_security_policy_report_only = false
end
