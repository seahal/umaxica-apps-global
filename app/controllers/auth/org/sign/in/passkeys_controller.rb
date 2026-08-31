# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        # Renders the passkey sign-in entry page for the staff surface.
        #
        # The ceremony itself is not served here. Auth::Org::Sign::In::Passkey::OptionsController
        # issues the bound challenge and Auth::Org::Sign::In::Passkey::VerificationsController
        # consumes the assertion and commits the login; only #new is routed to this
        # controller, so it carries no credential work and no response-time budget.
        class PasskeysController < ::Auth::Org::ApplicationController
          include ::TurnstilePageProps
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest

          # GET /in/passkeys/new
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
        end
      end
    end
  end
end
