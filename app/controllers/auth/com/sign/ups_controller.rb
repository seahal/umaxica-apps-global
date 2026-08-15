# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class UpsController < ::Auth::Com::ApplicationController
        include SignUpSuspensionGuard
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :guest

        before_action :reject_suspended_sign_up!
        declare_authentication_mode! :guest, no_redirect: true

        def show
          return reject_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
              surface: "com",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_up"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render inertia: "auth/com/sign_ups/new", props: sign_up_method_props
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"),
                 status: :bad_request
        end

        private

        def sign_up_surface = :com

        # `SignUpSuspensionGuard` re-renders this surface's own entry page; that page is an Inertia
        # component rather than a template, and the 503 stays exactly as it was.
        def render_suspended_sign_up!
          render inertia: "auth/com/sign_ups/new", props: sign_up_method_props, status: :service_unavailable
        end

        def reject_logged_in_direct_entry!
          render plain: I18n.t("errors.messages.already_authenticated"), status: :forbidden
        end

        # Direct entry without an authorization transaction renders this surface's entry page instead
        # of bouncing through Base. Every page it links to is already reachable directly, and the
        # completion paths branch on a missing `oidc_authorization_login_challenge`.
        def render_method_selection!
          render inertia: "auth/com/sign_ups/new", props: sign_up_method_props
        end

        # `@sign_up_available == false` means the sign_up_suspended_<surface> kill switch is on:
        # send the notice instead of entry points that would start a registration the guard is
        # about to reject anyway.
        def sign_up_method_props
          suspended = @sign_up_available == false
          entry_params = { ct: params[:ct], ri: params[:ri] }

          {
            title: t("sign.app.registration.new.page_title"),
            description: nil,
            suspended_notice: suspended ? t("errors.messages.sign_up_suspended") : nil,
            methods: suspended ? [] : sign_up_method_links(entry_params),
            links: suspended ? [] : sign_up_footer_links(entry_params),
          }
        end

        def sign_up_method_links(entry_params)
          [
            {
              key: "email",
              label: t("sign.app.registration.new.methods.email.cta"),
              href: new_auth_com_sign_up_email_path(**entry_params),
            },
            {
              key: "telephone",
              label: t("sign.app.registration.new.methods.telephone.cta"),
              href: new_auth_com_sign_up_telephone_path(**entry_params),
            },
          ]
        end

        def sign_up_footer_links(entry_params)
          [
            {
              key: "sign_in",
              label: t("sign.app.registration.new.links.sign_in"),
              href: auth_com_sign_in_path(**entry_params),
            },
          ]
        end
      end
    end
  end
end
