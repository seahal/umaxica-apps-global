# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class InsController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest, no_redirect: true

        def show
          return reject_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
              surface: "org",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_in"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render inertia: true, props: sign_in_entry_props
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"),
                 status: :bad_request
        end

        private

        def reject_logged_in_direct_entry!
          render plain: I18n.t("errors.messages.already_authenticated"), status: :forbidden
        end

        # Direct entry without an authorization transaction renders this surface's entry page instead
        # of bouncing through Base. Every page it links to is already reachable directly, and the
        # completion paths branch on a missing `oidc_authorization_login_challenge`.
        def render_method_selection!
          render inertia: true, props: sign_in_entry_props
        end

        # One list, one item per sign-in method, so the Entra button sits on the same line as the
        # passkey and secret-credential links rather than below them. Entra needs the
        # organization's connection before a tenant can be chosen, so its entry posts to the
        # surface ceremony endpoint, which renders one cushion page and only then hands the POST to
        # the OmniAuth request phase. Button wording is governed by
        # docs/reference/third-party-sign-in-button-requirements.md.
        def sign_in_entry_props
          pt = signed_pt_param
          region = params[:ri]

          {
            title: t("sign.org.authentication.new.page_title"),
            description: t("sign.org.authentication.new.description"),
            methods: [
              {
                key: "passkey",
                kind: "link",
                label: t("sign.org.authentication.new.links.passkey"),
                href: new_auth_org_sign_in_passkey_path(pt: pt, ri: region),
              },
              {
                key: "secret_credential",
                kind: "link",
                label: t("sign.org.authentication.new.links.secret_credential"),
                href: new_auth_org_sign_in_secret_path(pt: pt, ri: region),
              },
              {
                key: "entra",
                kind: "provider",
                label: t("sign.org.authentication.new.links.entra"),
                href: auth_org_social_entra_session_path(pt: pt, ri: region),
              },
            ],
            # Direct entry only. An RP-initiated ceremony asked for a sign-in, so the page must not
            # offer a detour into sign-up; the same rule governs the reciprocal link on
            # auth/org/sign/ups#show.
            registration_link: if @oidc_authorization_intent.blank?
                                 {
                                   label: t("sign.org.authentication.new.links.registration"),
                                   href: auth_org_sign_up_path(pt: pt, ri: region),
                                 }
                               end,
            back_to_root: {
              label: t("sign.org.authentication.new.back_to_root"),
              href: auth_org_root_url(host: ENV.fetch("PRIVATE_BASE_STAFF_URL")),
            },
          }
        end
      end
    end
  end
end
