# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module In
        module Passkey
          class OptionsController < ::Sign::App::Sign::In::PasskeysController
            AUTHENTICATION_MODE = :guest
            declare_authentication_mode! :guest

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "sign_app_sign_in",
              name: "passkey_options_ip_burst",
              store: rate_limit_store,
              with: -> { render_rate_limited(rule_name: "sign_app_sign_in_passkey_options_ip_burst", retry_after: 60) },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "sign_app_sign_in",
              name: "passkey_options_ip_sustained",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(rule_name: "sign_app_sign_in_passkey_options_ip_sustained", retry_after: 900)
              },
            )

            def create = options
          end
        end
      end
    end
  end
end
