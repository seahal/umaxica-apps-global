# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      # Passkey registration and management for operators.
      #
      # Org passkeys are the surface's step-up / AAL2 credential (Entra ID
      # covers sign-in SSO only); registration requires step-up bootstrap and
      # the ceremony commits through the passkey ceremony contract.
      class PasskeysController < ::Auth::Org::ApplicationController
        include ::VerificationOperator
        include SignSettingsPasskeyRegistration
        include ::PasskeyRegistrationFlow
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
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
          @passkeys = current_operator.staff_passkeys.order(created_at: :asc)
        end

        def show
          authorize!(@passkey)
        end

        def new
          authorize!(OperatorPasskey, to: :new?)
          @passkey = current_operator.staff_passkeys.new
          start_passkey_ceremony!(_surface: "org", _actor: current_operator, _session_ref: current_session_public_id)
        end

        def edit
          authorize!(@passkey)
        end

        # WebAuthn registration is driven by new/options/verification; REST create
        # hands clients to that ceremony without mutating local Sign state.
        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_auth_org_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: {
                status: "registration_ceremony_required",
                redirect_path: new_auth_org_settings_passkey_path(ri: params[:ri]),
              }, status: :accepted
            end
          end
        end

        def options = (authorize!(OperatorPasskey, to: :create?); render_passkey_registration_options)

        def verification = (authorize!(OperatorPasskey, to: :create?); verify_passkey_registration)

        def update
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(auth_org_settings_passkey_path(@passkey, ri: params[:ri]), status: :see_other)
          else
            render :edit, status: :unprocessable_content
          end
        end

        def destroy
          authorize!(@passkey)
          unless AuthMethodGuard.can_remove_passkey?(current_operator, @passkey)
            redirect_to(
              auth_org_settings_passkeys_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          @passkey.destroy!
          redirect_to(auth_org_settings_passkeys_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_passkeys!
          authorize!(OperatorPasskey, to: :index?)
        end

        def authorize_passkey_create!
          authorize!(OperatorPasskey, to: :create?)
        end

        def verify_settings_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                auth_org_settings_passkeys_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
          end
          false
        end

        def set_passkey
          @passkey = current_operator.staff_passkeys.find(params.expect(:id))
        end

        def update_params
          key = %i(operator_passkey staff_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

          params.fetch(key, {}).permit(:description)
        end

        def passkey_registration_actor = current_operator

        def passkey_registration_passkeys = current_operator.staff_passkeys

        def passkey_registration_redirect_url
          auth_org_settings_passkeys_url(ri: params[:ri], host: base_authority_host)
        end

        # Org has no recovery-passcode top-up after registration; render the
        # ceremony result directly.
        def render_verification_success(passkey)
          render json: {
            status: "ok",
            passkey_id: passkey.id,
            redirect_url: bootstrap_return_path(passkey_registration_redirect_url),
          }, status: :created
        end

        def recovery_passcode_requirement_active_strong_credential_count
          0
        end

        def recovery_passcode_requirement_actor = current_operator

        def recovery_passcode_requirement_credential_class = OperatorSecretCredential

        def recovery_passcode_setup_url
          base_org_identity_secrets_url(
            ri: params[:ri],
            host: base_authority_host,
          )
        end
      end
    end
  end
end
