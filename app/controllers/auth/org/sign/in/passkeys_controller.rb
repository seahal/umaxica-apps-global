# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        # PasskeysController handles Passkey-based operator authentication.
        #
        # Flow:
        # 1. Operator visits /in/passkeys/new and enters their operator public_id
        # 2. POST /in/passkeys/options with identifier to get WebAuthn challenge
        # 3. Browser performs navigator.credentials.get()
        # 4. POST /in/passkeys/verification with credential + challenge_id
        # 5. Server verifies and establishes session via AuthenticationBase#log_in
        #
        # Note: Discoverable credentials (passwordless without identifier) are
        # planned for a future phase. Currently, identifier is required to look up
        # the operator's registered passkeys.
        class PasskeysController < ::Auth::Org::ApplicationController
          include MinimumResponseBudget

          include SessionLimitGate

          include CloudflareTurnstile

          include ::TurnstilePageProps
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          # GET /in/passkeys/new
          # Render login page with identifier input and passkey button
          def new
            render inertia: true, props: passkey_sign_in_props
          end

          private

          def passkey_sign_in_props
            pt = signed_pt_param
            region = current_region_identifier

            {
              title: t("sign.org.authentication.passkey.new.page_title"),
              description: t("sign.org.authentication.passkey.new.description"),
              panel: {
                options_url: auth_org_sign_in_passkey_options_path(pt: pt, ri: region),
                verification_url: auth_org_sign_in_passkey_verification_path(pt: pt, ri: region),
                region: region.to_s,
                identifier_param: "identifier",
                turnstile_site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY),
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: t("sign.org.authentication.passkey.new.identifier_label"),
                  placeholder: t("sign.org.authentication.passkey.new.identifier_placeholder"),
                  min_length: Operator::PUBLIC_ID_LENGTH,
                  max_length: Operator::PUBLIC_ID_LENGTH,
                  pattern: "[0-9A-FGHJKMNPQRSTVWXYZ]{16}",
                },
                submit_label: t("sign.org.authentication.passkey.new.submit"),
              },
              back_link: {
                label: t("sign.org.authentication.new.back"),
                href: auth_org_sign_in_path(pt: pt, ri: region),
              },
            }
          end

          def minimum_response_budget_enabled?
            action_name == "options"
          end
        end
      end
    end
  end
end
