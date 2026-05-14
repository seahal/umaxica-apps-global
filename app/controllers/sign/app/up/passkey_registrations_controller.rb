# typed: false
# frozen_string_literal: true

require "base64"

module Sign
  module App
    module Up
      class PasskeyRegistrationsController < ApplicationController
        include Sign::Webauthn
        include Common::Redirect

        before_action :set_user_telephone

        def show
          @success_redirect_url = success_redirect_url
        end

        def begin
          existing_credentials =
            @user.user_passkeys.map do |passkey|
              { id: passkey.webauthn_id }
            end

          challenge_id, creation_options = create_registration_challenge(
            resource: @user,
            exclude_credentials: existing_credentials,
          )

          render json: {
            challenge_id: challenge_id,
            options: creation_options,
          }, status: :ok
        rescue Sign::Webauthn::OriginValidationError => e
          Rails.event.error("webauthn.origin_validation_failed", error: e.message)
          render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
        rescue StandardError => e
          Rails.event.error("webauthn.options_generation_failed", error: e.message)
          render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
        end

        def create
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

            passkey = @user.user_passkeys.new(
              webauthn_id: credential.id,
              public_key: credential.public_key,
              sign_count: credential.sign_count,
              description: passkey_description,
            )
            passkey.save!

            if @user.status_id == UserStatus::UNVERIFIED_WITH_SIGN_UP
              @user.update!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
            end
            @user.create_user_account! unless @user.user_account

            record_signup_audit!(@user)
            log_in(
              @user,
              record_login_audit: true,
              audit_context: { auth_method: "passkey" },
            )
            create_welcome_bulletin!(@user)
            session[:user_telephone_registration] = nil

            render json: {
              status: "ok",
              redirect_url: sign_in_sequence_redirect_path(
                rt: params[:rt].presence,
                default_path: sign_app_configuration_path(ri: params[:ri]),
              ),
            }, status: :created
          end
        rescue Sign::Webauthn::ChallengeNotFoundError,
               Sign::Webauthn::ChallengeExpiredError,
               Sign::Webauthn::ChallengePurposeMismatchError => e
          Rails.logger.warn("WebAuthn challenge error: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue WebAuthn::Error => e
          Rails.logger.warn("WebAuthn verification failed: #{e.message}")
          render json: { error: e.message }, status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        private

        def set_user_telephone
          telephone_public_id = params[:telephone_id].presence || params[:telephone_public_id].presence
          @user_telephone = UserTelephone.find_by(public_id: telephone_public_id)
          registration_session = session[:user_telephone_registration] || {}
          session_public_id =
            registration_session[:public_id] || registration_session["public_id"]

          unless @user_telephone && session_public_id.to_s == @user_telephone.public_id.to_s
            if request.format.json?
              render json: {
                error: I18n.t("sign.app.registration.telephone.edit.session_expired"),
              }, status: :unprocessable_content
            else
              redirect_to(
                new_sign_app_up_telephone_path(ri: params[:ri]),
                notice: I18n.t("sign.app.registration.telephone.edit.session_expired"),
              )
            end
            return
          end

          if @user_telephone.user_telephone_status_id != UserTelephoneStatus::VERIFIED_WITH_SIGN_UP
            if request.format.json?
              render json: {
                error: I18n.t("sign.app.registration.telephone.update.passkey_required"),
              }, status: :unprocessable_content
            else
              redirect_to(edit_sign_app_up_telephone_path(@user_telephone, ri: params[:ri]))
            end
            return
          end

          @user = @user_telephone.user
        end

        def record_signup_audit!(user)
          audit = UserChronicle.new
          audit.actor_type = "User"
          audit.actor_id = user.id
          audit.event_id = UserChronicleEvent::SIGNED_UP_WITH_TELEPHONE
          audit.subject_id = user.id.to_s
          audit.subject_type = "User"
          audit.save!
        end

        def credential_params
          params.expect(
            credential: [
              :id,
              :rawId,
              :type,
              :authenticatorAttachment,
              { transports: [] },
              { response: %i(clientDataJSON attestationObject) },
              { clientExtensionResults: {} },
            ],
          ) || {}
        end

        def passkey_description
          params[:description].presence || I18n.t("sign.default_passkey_description")
        end

        def success_redirect_url
          rt_param = params[:rt].presence
          sign_in_checkpoint_path(rt: rt_param)
        end
      end
    end
  end
end
