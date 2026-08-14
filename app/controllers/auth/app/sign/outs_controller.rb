# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class OutsController < ::Auth::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::SignOutCancellation
        include ::OidcRpLogoutLauncher
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render inertia: "auth/app/sign/outs/edit", props: sign_out_confirmation_props
        end

        def create
          # Coordinated logout continuation. Core, Side, and Palm origins run a three-step
          # ceremony whose `sign_cleared` hop lands here after Base has cleared its own state,
          # and the one-shot logout challenge is the proof for that cross-host post. A
          # user-initiated sign-out on this surface carries no challenge and starts a fresh
          # RP logout toward the Base end-session endpoint instead.
          return continue_coordinated_sign_out! if params[:logout_challenge].present?

          launch_oidc_rp_logout!(
            client_id: "sign-rp",
            issuer_resource_type: "client",
            token_issuer: "client",
          )
        end

        def complete
          complete_oidc_rp_logout!
        end

        private

        # The three shared sign-out templates become Inertia pages on this surface only. `auth/com`
        # and `auth/org` still render the ERB under `app/views/auth/shared/sign_outs`, so the
        # shared concerns keep their template renders and this controller overrides them locally.
        def sign_out_confirmation_props
          {
            title: t("sign.shared.sign_out.title"),
            heading: t("sign.shared.sign_out.title"),
            active_context: sign_out_active_context_present?,
            confirm_description: t("sign.shared.sign_out.confirm_description"),
            already_signed_out: t("sign.shared.sign_out.already_signed_out"),
            submit_label: t("sign.shared.sign_out.button"),
            form: {
              action: sign_out_confirmation_form_path,
              logout_challenge: params[:logout_challenge].presence,
            },
            cancel: {
              label: t("actions.cancel"),
              action: sign_out_post_path,
            },
            home_link: sign_out_home_link,
          }
        end

        def sign_out_completion_props
          {
            title: t("sign.shared.sign_out.completed_title"),
            heading: t("sign.shared.sign_out.completed_title"),
            description: sign_out_completed_description,
            home_link: sign_out_home_link,
          }
        end

        def sign_out_unavailable_props
          {
            title: t("sign.shared.sign_out.unavailable_title"),
            heading: t("sign.shared.sign_out.unavailable_title"),
            description: t("sign.shared.sign_out.unavailable_description"),
            retry: {
              label: t("sign.shared.sign_out.retry_button"),
              action: sign_out_confirmation_form_path,
            },
            home_link: sign_out_home_link,
          }
        end

        def sign_out_home_link
          { label: t("sign.shared.sign_out.home_link"), href: sign_out_home_path }
        end

        def render_oidc_rp_logout_completion
          @sign_out_notice = consume_sign_out_notice
          render inertia: "auth/app/sign/outs/complete", props: sign_out_completion_props, status: :ok
        end

        def render_oidc_rp_logout_unavailable
          render inertia: "auth/app/sign/outs/unavailable",
                 props: sign_out_unavailable_props,
                 status: :unprocessable_content
        end

        def continue_coordinated_sign_out!
          cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)
          logout_current_session!(reason: "user_logout")

          redirect_to(
            auth_app_sign_out_completion_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
              protocol: "https",
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
