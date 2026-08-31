# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        # Renders the passkey sign-in entry page: an identifier field and the
        # button that starts the ceremony in the browser.
        #
        # The ceremony itself is not served here. Auth::App::Sign::In::Passkey::OptionsController
        # issues the bound challenge and Auth::App::Sign::In::Passkey::VerificationsController
        # consumes the assertion and commits the login; only #new is routed to this
        # controller, so it carries no credential work and no response-time budget.
        class PasskeysController < ::Auth::App::ApplicationController
          include ::SurfaceInertiaPage

          AUTHENTICATION_MODE = :guest

          # GET /in/passkeys/new
          def new
            render inertia: true, props: passkey_new_props
          end

          private

          def passkey_new_props
            scope = "sign.app.authentication.passkey.new"
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: page_t("#{scope}.page_title"),
              description: page_t("#{scope}.description"),
              panel: {
                options_url: auth_app_sign_in_passkey_options_path(pt: pt, ri: ri),
                verification_url: auth_app_sign_in_passkey_verification_path(pt: pt, ri: ri),
                region: ri.to_s,
                identifier_param: "identifier",
                # The stealth site key is public by design and the ERB already published it in the
                # rendered HTML; the secret key and the token verification stay server side.
                turnstile_site_key: JitSecurityTurnstileConfig.stealth_site_key.to_s,
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: page_t("#{scope}.pii_label"),
                  placeholder: page_t("#{scope}.pii_placeholder"),
                },
                submit_label: page_t("#{scope}.submit"),
              },
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_app_sign_in_path(pt: pt, ri: ri),
              },
            }
          end
        end
      end
    end
  end
end
