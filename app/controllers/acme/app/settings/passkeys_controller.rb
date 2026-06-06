# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      class PasskeysController < Acme::App::ApplicationController
        include CloudflareTurnstile
        include ::VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_passkeys!, only: :index
        before_action :set_passkey, only: %i(show edit update destroy)

        def index
          @passkeys = authorized_scope(current_client.client_passkeys).order(created_at: :desc)
        end

        def enrollment
          authorize!(ClientPasskey, to: :create?)
          issuance = IdentityPasskeyCeremonyGrantIssuer.issue!(
            surface: "app",
            actor_ref: current_client.public_id,
            session_ref: current_session_public_id,
            operation: "registration",
          )
          redirect_to(
            new_sign_app_settings_passkey_url(
              ri: params[:ri],
              passkey_ceremony_grant: issuance.grant,
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            status: :see_other,
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def show
          authorize!(@passkey)
        end

        def edit
          authorize!(@passkey)
        end

        def update
          authorize!(@passkey)
          return render_turnstile_failure(:edit) unless cloudflare_turnstile_stealth_validation["success"]

          if @passkey.update(update_params)
            redirect_to(
              acme_app_settings_passkey_path(@passkey, ri: params[:ri]),
              notice: t("messages.passkey_successfully_updated"),
              status: :see_other,
            )
          else
            render :edit, status: :unprocessable_content
          end
        end

        def destroy
          authorize!(@passkey)
          return redirect_last_method unless AuthMethodGuard.can_remove_passkey?(current_client, @passkey)
          return redirect_turnstile_failure unless cloudflare_turnstile_stealth_validation["success"]

          @passkey.destroy!
          redirect_to(
            acme_app_settings_passkeys_path(ri: params[:ri]),
            notice: t("messages.passkey_successfully_destroyed"),
            status: :see_other,
          )
        end

        private

        def authorize_passkeys!
          authorize!(ClientPasskey, to: :index?)
        end

        def set_passkey
          @passkey = current_client.client_passkeys.find_by!(public_id: params(:id))
        end

        def update_params
          key = %i(client_passkey user_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

          params.fetch(key, {}).permit(:description)
        end

        def render_turnstile_failure(template)
          @passkey.errors.add(:base, t("turnstile_error"))
          flash.now[:alert] = t("turnstile_error")
          render template, status: :unprocessable_content
        end

        def redirect_turnstile_failure
          redirect_to(
            acme_app_settings_passkeys_path(ri: params[:ri]),
            alert: t("turnstile_error"),
            status: :see_other,
          )
        end

        def redirect_last_method
          redirect_to(
            acme_app_settings_passkeys_path(ri: params[:ri]),
            alert: t("messages.cannot_delete_last_passkey"),
            status: :see_other,
          )
        end

        def verification_required_action?
          %w(edit update destroy enrollment).include?(action_name)
        end

        def verification_scope
          "settings_passkey"
        end
      end
    end
  end
end
