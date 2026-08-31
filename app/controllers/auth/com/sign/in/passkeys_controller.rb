# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        # Renders the passkey sign-in entry page for the corporate surface.
        #
        # The ceremony itself is not served here. Auth::Com::Sign::In::Passkey::OptionsController
        # issues the bound challenge and Auth::Com::Sign::In::Passkey::VerificationsController
        # consumes the assertion and commits the login; only #new is routed to this
        # controller, so it carries no credential work and no response-time budget.
        class PasskeysController < ::Auth::Com::ApplicationController
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :guest

          def new
            render inertia: true, props: sign_in_passkey_new_props
          end

          private

          def sign_in_passkey_new_props
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: t("sign.app.authentication.passkey.new.page_title"),
              description: t("sign.app.authentication.passkey.new.description"),
              panel: {
                options_url: auth_com_sign_in_passkey_options_path(pt: pt, ri: ri),
                verification_url: auth_com_sign_in_passkey_verification_path(pt: pt, ri: ri),
                region: ri.to_s,
                identifier_param: "identifier",
                turnstile_site_key: turnstile_stealth_props.fetch(:site_key),
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: t("sign.app.authentication.passkey.new.pii_label"),
                  placeholder: t("sign.app.authentication.passkey.new.pii_placeholder"),
                  min_length: 0,
                  max_length: 255,
                  pattern: ".*",
                },
                submit_label: t("sign.app.authentication.passkey.new.submit"),
              },
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_com_sign_in_path(pt: pt, ri: ri),
              },
            }
          end
        end
      end
    end
  end
end
