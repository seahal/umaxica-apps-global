# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class PasskeysController < PrivateController
        include ::Verification::Visitor
        include Sign::Webauthn

        before_action :authenticate_visitor!
        before_action only: %i(new create options verification) do
          require_step_up_unless_bootstrap!(scope: verification_scope)
        end
        before_action :set_passkey, only: %i(show edit update destroy)

        def index
          @passkeys = current_visitor.visitor_passkeys.order(created_at: :desc)
        end

        def show
        end

        def new
          @passkey = current_visitor.visitor_passkeys.new
        end

        def edit
        end

        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_sign_com_configuration_passkey_path,
                alert: t("messages.not_implemented"),
              )
            end
            format.json do
              render json: { error: t("messages.not_implemented") }, status: :unprocessable_content
            end
          end
        end

        def options
          existing_credentials = current_visitor.visitor_passkeys.map { |passkey| { id: passkey.webauthn_id } }
          challenge_id, creation_options = create_registration_challenge(
            resource: current_visitor,
            exclude_credentials: existing_credentials,
          )

          render json: {
            challenge_id: challenge_id,
            options: creation_options,
          }, status: :ok
        rescue Sign::Webauthn::OriginValidationError => e
          Rails.event.error("webauthn.origin_validation_failed", message: e.message)
          render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
        rescue Sign::Webauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
          Rails.event.error("webauthn.registration_options_failed", error_class: e.class.name, message: e.message)
          render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
        end

        def verification
          challenge_id = params[:challenge_id]
          if challenge_id.blank?
            return render json: {
              error: I18n.t("errors.webauthn.challenge_id_required"),
            }, status: :bad_request
          end

          with_challenge(challenge_id, purpose: :registration) do |challenge|
            credential = WebAuthn::Credential.from_create(
              credential_params.to_h,
              relying_party: webauthn_relying_party,
            )

            credential.verify(challenge)

            passkey = current_visitor.visitor_passkeys.new(
              webauthn_id: credential.id,
              public_key: credential.public_key,
              sign_count: credential.sign_count,
              description: passkey_description,
            )

            passkey.save!

            render json: {
              status: "ok",
              passkey_id: passkey.id,
              redirect_url: bootstrap_return_path(sign_com_configuration_passkeys_path),
            }, status: :created
          end
        rescue Sign::Webauthn::ChallengeNotFoundError,
               Sign::Webauthn::ChallengeExpiredError => e
          Rails.logger.warn("WebAuthn challenge error: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue Sign::Webauthn::ChallengePurposeMismatchError => e
          Rails.logger.warn("WebAuthn challenge purpose mismatch: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue WebAuthn::Error => e
          Rails.logger.warn("WebAuthn registration failed: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn("WebAuthn passkey creation failed: #{e.message}")
          render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        def update
          if @passkey.update(update_params)
            respond_to do |format|
              format.html do
                redirect_to(
                  sign_com_configuration_passkey_path(@passkey),
                  notice: t("messages.passkey_successfully_updated"),
                )
              end
              format.json { render json: { status: "ok" }, status: :ok }
            end
          else
            respond_to do |format|
              format.html { render :edit, status: :unprocessable_content }
              format.json do
                render json: { errors: @passkey.errors.full_messages }, status: :unprocessable_content
              end
            end
          end
        end

        def destroy
          unless AuthMethodGuard.can_remove_passkey?(current_visitor, @passkey)
            respond_to do |format|
              format.html do
                redirect_to(
                  sign_com_configuration_passkeys_path,
                  status: :see_other,
                  alert: t("messages.cannot_delete_last_passkey"),
                )
              end
              format.json do
                render json: { error: t("messages.cannot_delete_last_passkey") },
                       status: :unprocessable_content
              end
            end
            return
          end

          @passkey.destroy!

          respond_to do |format|
            format.html do
              redirect_to(
                sign_com_configuration_passkeys_path,
                status: :see_other,
                notice: t("messages.passkey_successfully_destroyed"),
              )
            end
            format.json { head :no_content }
          end
        end

        private

        def set_passkey
          passkey_id = params(:id)
          @passkey = current_visitor.visitor_passkeys.find_by(public_id: passkey_id)
          @passkey ||= current_visitor.visitor_passkeys.find(passkey_id) if passkey_id.to_s.match?(/\A\d+\z/)
          raise ActiveRecord::RecordNotFound unless @passkey
        end

        def credential_params
          params.fetch(:credential, {}).permit(
            :id,
            :rawId,
            :type,
            :authenticatorAttachment,
            { transports: [] },
            { response: %i(clientDataJSON attestationObject) },
            { clientExtensionResults: {} },
          )
        end

        def update_params
          key = params.key?(:visitor_passkey) ? :visitor_passkey : :passkey
          params.fetch(key, {}).permit(:description)
        end

        def passkey_description
          params[:description].presence || I18n.t("sign.default_passkey_description")
        end

        def verification_required_action?
          step_up_bootstrap_active?
        end

        def verification_scope
          "configuration_passkey"
        end
      end
    end
  end
end
