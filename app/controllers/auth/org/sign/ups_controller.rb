# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class UpsController < ::Auth::Org::ApplicationController
        include SignUpSuspensionGuard
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :guest

        before_action :reject_suspended_sign_up!
        helper Auth::Org::SignUpsHelper
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
                "authorization transaction intent mismatch" unless transaction.intent == "sign_up"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render inertia: true, props: sign_up_entry_props
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"),
                 status: :bad_request
        end

        private

        def sign_up_surface = :org

        def render_suspended_sign_up!
          render inertia: "auth/org/sign/ups/show", props: suspended_props, status: :service_unavailable
        end

        def reject_logged_in_direct_entry!
          render plain: I18n.t("errors.messages.already_authenticated"), status: :forbidden
        end

        # Direct entry without an authorization transaction renders this surface's entry page instead
        # of bouncing through Base. Every page it links to is already reachable directly, and the
        # completion paths branch on a missing `oidc_authorization_login_challenge`.
        def render_method_selection!
          render inertia: true, props: sign_up_entry_props
        end

        def sign_up_entry_props
          region = params[:ri]

          {
            title: t("sign.org.ups.new.heading"),
            description: t("sign.org.ups.new.description"),
            suspended_notice: nil,
            recruit: {
              prompt: t("sign.org.ups.new.recruit_prompt"),
              label: t("sign.org.ups.new.recruit_link_text"),
              href: helpers.sign_org_recruit_contact_url,
            },
            # Direct entry only. An RP-initiated ceremony asked for a sign-up, so the page must not
            # offer a detour into sign-in; the same rule governs the reciprocal link on
            # auth/org/sign/ins#show.
            sign_in_link: if @oidc_authorization_intent.blank?
                            {
                              label: t("sign.org.ups.new.links.sign_in"),
                              href: auth_org_sign_in_path(pt: signed_pt_param, ri: region),
                            }
                          end,
            back_to_root: {
              label: t("sign.org.ups.new.back_to_root"),
              href: auth_org_root_path,
            },
          }
        end

        # The sign_up_suspended_org kill switch is on: send the notice instead of entry points that
        # would start a registration the guard is about to reject anyway.
        def suspended_props
          {
            title: t("sign.org.ups.new.heading"),
            description: nil,
            suspended_notice: t("errors.messages.sign_up_suspended"),
            recruit: nil,
            sign_in_link: nil,
            back_to_root: nil,
          }
        end
      end
    end
  end
end
