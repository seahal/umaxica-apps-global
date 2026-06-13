# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class TelephonesController < ::Sign::Com::ApplicationController
        include CommonOtp
        include ::SignSettingsAuthorityRedirect

        include ::VerificationVisitor

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :open, only: %i(index destroy)
        declare_authentication_mode! :private, only: %i(new create edit)

        TELEPHONE_VERIFICATION_RATE_LIMIT = 5
        TELEPHONE_VERIFICATION_RATE_WINDOW = 60
        before_action :authenticate_visitor!, except: %i(index destroy)
        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find_by! is owner-scoped, so a non-owner gets 404 first).
        # Verification/rate-limit guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def new
          @user_telephone = VisitorTelephone.new
        end

        def edit
          @user_telephone = current_visitor.visitor_telephones.find_by!(public_id: params(:id))
          authorize!(@user_telephone)
        end

        def create
          visitor = current_visitor
          return head :unauthorized if visitor.blank?

          tel_params = params(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: true)
            redirect_to(edit_sign_com_settings_telephones_registration_path(ri: params[:ri]))
          else
            render :new, status: :unprocessable_content
          end
        end

        private

        def authorize_telephone_registration!
          authorize!(VisitorTelephone, to: :create?)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_telephone"
        end

        def initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: false)
          return false if visitor.blank?

          check_telephone_verification_rate_limit!

          digest = IdentifierBlindIndex.bidx_for_telephone(number)
          existing_visitor_telephone =
            digest.present? ? visitor.visitor_telephones.find_by(number_digest: digest) : nil

          @user_telephone = existing_visitor_telephone || visitor.visitor_telephones.build(raw_number: number)
          @user_telephone.raw_number = number if existing_visitor_telephone
          @user_telephone.visitor_telephone_status_id = VisitorTelephoneStatus::UNVERIFIED
          if auto_accept_confirmations
            @user_telephone.confirm_policy = true
            @user_telephone.confirm_using_mfa = true
          end

          if digest.present? && existing_visitor_telephone.blank?
            VisitorTelephone.where(
              number_digest: digest,
              visitor_id: visitor.id,
              visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
            ).destroy_all
          end

          otp_number = generate_otp_attributes(@user_telephone)
          return false unless @user_telephone.valid?

          @user_telephone.save!
          send_telephone_verification_sms(@user_telephone, otp_number)
          true
        end

        def send_telephone_verification_sms(visitor_telephone, otp_number)
          message = I18n.t("sign.telephone_verification.sms_message", code: otp_number)
          OutboundSms.deliver_later(
            to: visitor_telephone.number,
            title: message,
            body: message,
          )
        end

        def check_telephone_verification_rate_limit!
          cache_key = "rate-limit:telephone_verification:#{request.remote_ip}"
          count = Rails.configuration.x.rate_limit.fetch(:store).increment(
            cache_key,
            1,
            expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds,
          )
          return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

          Rails.logger.info(
            JitLogEvent.format(
              "telephone.verification.rate_limited",
              ip: request.remote_ip,
              retry_after: TELEPHONE_VERIFICATION_RATE_WINDOW,
            ),
          )
          raise ActionController::TooManyRequests
        end
      end
    end
  end
end
