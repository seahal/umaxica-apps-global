# typed: false
# frozen_string_literal: true

module Base
  module App
    class SignOutsController < Base::App::ApplicationController
      include ::AuthenticationLogoutable
      include ::SignOutNotice
      include ::SignOidcLogout
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open
      # `reject_oidc_logout_challenge!` still renders the shared `auth/shared/sign_outs/unavailable`
      # ERB template, which needs the surface ERB layout; the Inertia shell renders only an Inertia
      # response body.
      layout -> { @render_surface_erb_layout ? "base/app/application" : "base/app/inertia" }

      declare_authentication_mode! :open
      after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

      def new
        redirect_to(sign_out_edit_path, status: :see_other)
      end

      def edit
        render inertia: "base/app/sign_outs/edit", props: sign_out_edit_page_props
      end

      def create
        if current_resource.blank? && current_session_public_id.blank?
          return render_oidc_logout_completion
        end

        prepare_sign_out_completion_notice!
        logout_current_session!(reason: "user_logout")
        issue_sign_out_notice!
        redirect_to(sign_out_complete_path, status: :see_other)
      end

      def complete
        render_oidc_logout_completion
      end

      private

      def reject_oidc_logout_challenge!(reason)
        @render_surface_erb_layout = true
        super
      end

      def render_oidc_logout_completion
        @sign_out_notice = consume_sign_out_notice
        render inertia: "base/app/sign_outs/complete",
               props: sign_out_complete_page_props,
               status: :ok
      end

      def sign_out_edit_page_props
        active = sign_out_active_context_present?

        {
          title: t("sign.shared.sign_out.title"),
          active: active,
          description: active ? t("sign.shared.sign_out.confirm_description") : t("sign.shared.sign_out.already_signed_out"),
          form: active ? sign_out_confirmation_form : nil,
          home_link: { label: t("sign.shared.sign_out.home_link"), href: sign_out_home_path },
        }
      end

      def sign_out_confirmation_form
        {
          action: sign_out_post_path,
          submit: t("sign.shared.sign_out.button"),
          logout_challenge: params[:logout_challenge].presence,
          confirm_description: t("sign.shared.sign_out.confirm_description"),
        }
      end

      def sign_out_complete_page_props
        {
          title: t("sign.shared.sign_out.completed_title"),
          description: sign_out_completed_description,
          home_link: { label: t("sign.shared.sign_out.home_link"), href: sign_out_home_path },
        }
      end

      def sign_out_confirmation_form_path
        sign_out_post_path
      end
    end
  end
end
