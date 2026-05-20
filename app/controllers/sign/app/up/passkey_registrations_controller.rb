# typed: false
# frozen_string_literal: true

require "base64"

module Sign
  module App
    module Up
      class PasskeyRegistrationsController < GuestController
        include Sign::Webauthn
        include Common::Redirect

        before_action :set_user_telephone
        before_action :set_sign_up_cycle
        before_action :authorize_passkey_requirement!

        def show
          @success_redirect_url = success_redirect_url
        end

        def begin
          existing_credentials =
            @user.client_passkeys.map do |passkey|
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
            credential = verified_registration_credential(challenge)
            create_user_passkey!(credential)
            return unless clear_passkey_requirement!

            render_created_passkey_registration
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

        def verified_registration_credential(challenge)
          WebAuthn::Credential.from_create(
            credential_params.to_h,
            relying_party: webauthn_relying_party,
          ).tap { |credential| credential.verify(challenge) }
        end

        def create_user_passkey!(credential)
          @user.client_passkeys.create!(
            webauthn_id: credential.id,
            public_key: credential.public_key,
            sign_count: credential.sign_count,
            description: passkey_description,
          )
        end

        def clear_passkey_requirement!
          result =
            AppTicketRecord.connected_to(role: :writing) do
              SignUp::StateMachine.call(
                ticket: @sign_up_cycle,
                event: :clear_requirement,
                actor_context: sign_up_actor_authentication,
                payload: { requirement: :passkey },
              )
            end
          return true if result.success?

          render json: { error: result.errors.to_sentence }, status: :unprocessable_content
          false
        end

        def render_created_passkey_registration
          render json: {
            status: "ok",
            redirect_url: success_redirect_url,
          }, status: :created
        end

        def set_user_telephone
          registration_session = session[:user_telephone_registration] || {}
          telephone_public_id =
            params[:telephone_id].presence ||
            params[:telephone_public_id].presence ||
            registration_session[:public_id] ||
            registration_session["public_id"]
          @user_telephone = ClientTelephone.find_by(public_id: telephone_public_id)
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

          # The telephone is intentionally still UNVERIFIED_WITH_SIGN_UP here:
          # OTP success only proved ownership for this cycle and recorded it in
          # the registration session. The durable VERIFIED transition happens
          # in the finalizer once the passkey exists.
          otp_verified =
            registration_session[:otp_verified] || registration_session["otp_verified"]
          telephone_pending =
            @user_telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP

          unless otp_verified && telephone_pending
            if request.format.json?
              render json: {
                error: I18n.t("sign.app.registration.telephone.update.passkey_required"),
              }, status: :unprocessable_content
            else
              redirect_to(edit_sign_app_up_telephone_path(ri: params[:ri]))
            end
            return
          end

          @user = @user_telephone.user
        end

        def set_sign_up_cycle
          @sign_up_cycle = sign_up_cycle_locator.current
          return if @sign_up_cycle

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
        end

        def authorize_passkey_requirement!
          return if performed?
          return if allowed_to?(:register_passkey?, passkey_requirement_context, with: SignUp::RequirementPolicy)

          if request.format.json?
            render json: {
              error: I18n.t("errors.messages.not_authorized"),
            }, status: :forbidden
          else
            redirect_to(sign_app_up_checkpoint_path(ri: params[:ri], rt: params[:rt].presence))
          end
        end

        def credential_params
          params(
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
          sign_app_up_checkpoint_path(ri: params[:ri], rt: params[:rt].presence)
        end

        def passkey_requirement_context
          SignUp::RequirementContext.build(
            surface: :app,
            actor_authentication: sign_up_actor_authentication,
            ticket: @sign_up_cycle,
            requirement: :passkey,
            pending_actor: @user,
          )
        end

        def sign_up_actor_authentication
          Actor::Authentication.new(
            login_public_id: Actor.authentication.login_public_id,
            access_claims: Actor.authentication.access_claims,
            acr: Actor.authentication.acr,
            amr: Actor.authentication.amr,
            actor_type: Actor.authentication.actor_type,
            actor_id: Actor.authentication.actor_id,
            restricted: Actor.authentication.restricted?,
            active_sign_sequence_id: @sign_up_cycle&.public_id,
          )
        end

        def sign_up_cycle_locator
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpCycle)
        end
      end
    end
  end
end
