# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Settings
      # Passkey registration and management for visitors.
      class PasskeysController < ::Auth::Com::ApplicationController
        include ::VerificationVisitor
        include SignSettingsPasskeyRegistration
        include ::PasskeyRegistrationFlow
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        # Object-level authorization (ActionPolicy): index/create gate the actor type; show/edit/
        # update/destroy authorize the owned record (set_passkey is owner-scoped -> 404 first).
        # Step-up / Turnstile / WebAuthn-challenge guards remain in place for the registration ceremony.
        before_action :authorize_passkeys!, only: %i(index)
        before_action :authorize_passkey_create!, only: %i(create)
        step_up only: %i(new create options verification), bootstrap: true
        step_up only: :destroy
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create options verification)
        before_action :set_passkey, only: %i(show edit update destroy)
        before_action :verify_settings_passkey_turnstile!, only: :options

        def index
          @passkeys = current_visitor.visitor_passkeys.order(created_at: :asc)
        end

        def show
          authorize!(@passkey)
        end

        def new
          @passkey = current_visitor.visitor_passkeys.new
          start_passkey_ceremony!(surface: "com", actor: current_visitor, session_ref: current_session_public_id)
        end

        def edit
          authorize!(@passkey)
        end

        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_auth_com_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: {
                status: "registration_ceremony_required",
                redirect_path: new_auth_com_settings_passkey_path(ri: params[:ri]),
              }, status: :accepted
            end
          end
        end

        def options = render_passkey_registration_options

        def verification = verify_passkey_registration

        def update
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(auth_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]), status: :see_other)
          else
            render :edit, status: :unprocessable_content
          end
        end

        def destroy
          authorize!(@passkey)
          unless AuthMethodGuard.can_remove_passkey?(current_visitor, @passkey)
            redirect_to(
              auth_com_settings_passkeys_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          @passkey.destroy!
          redirect_to(auth_com_settings_passkeys_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_passkeys!
          authorize!(VisitorPasskey, to: :index?)
        end

        def authorize_passkey_create!
          authorize!(VisitorPasskey, to: :create?)
        end

        def verify_settings_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                auth_com_settings_passkeys_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
          end
          false
        end

        def set_passkey
          @passkey = current_visitor.visitor_passkeys.find_by!(public_id: params.expect(:id))
        end

        def update_params
          key = params.key?(:visitor_passkey) ? :visitor_passkey : :passkey
          params.fetch(key, {}).permit(:description)
        end

        def passkey_registration_actor = current_visitor

        def passkey_registration_passkeys = current_visitor.visitor_passkeys

        def passkey_registration_redirect_url
          auth_com_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"))
        end

        def recovery_passcode_requirement_active_strong_credential_count
          current_visitor.visitor_passkeys.active.count
        end

        def recovery_passcode_requirement_actor = current_visitor

        def recovery_passcode_requirement_credential_class = VisitorSecretCredential

        def recovery_passcode_setup_url
          base_com_identity_url(
            ri: params[:ri],
            host: base_authority_host,
          )
        end

        def recovery_passcode_top_up_actor = current_visitor

        def recovery_passcode_top_up_credential_class = VisitorSecretCredential

        def recovery_passcode_reveal_redirect_url(token)
          base_com_identity_url(
            ri: params[:ri],
            token: token,
            host: base_authority_host,
          )
        end
      end
    end
  end
end
