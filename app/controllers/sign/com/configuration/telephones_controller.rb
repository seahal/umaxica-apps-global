# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class TelephonesController < Sign::Com::ApplicationController
        include Common::Otp

        include ::Verification::Visitor

        AUTHENTICATION_MODE = :private

        TELEPHONE_VERIFICATION_RATE_LIMIT = 5
        TELEPHONE_VERIFICATION_RATE_WINDOW = 60
        before_action :authenticate_visitor!

        def index
          @client_telephones = current_visitor.visitor_telephones.order(created_at: :asc)
        end

        def new
          @user_telephone = VisitorTelephone.new
        end

        def edit
          @user_telephone = current_visitor.visitor_telephones.find_by!(public_id: params(:id))
        end

        def create
          visitor = current_visitor
          return head :unauthorized if visitor.blank?

          tel_params = params(user_telephone: [:raw_number, :number])
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: true)
            redirect_to(edit_sign_com_configuration_telephone_path(@user_telephone.id, ri: params[:ri]))
          else
            render :new, status: :unprocessable_content
          end
        end

        def destroy
          telephone = current_visitor.visitor_telephones.find_by!(public_id: params(:id))

          unless AuthMethodGuard.can_remove_telephone?(current_visitor, telephone)
            redirect_to(
              sign_com_configuration_telephones_path(ri: params[:ri]),
              alert: t("sign.app.configuration.telephone.destroy.last_method"),
            )
            return
          end

          telephone.destroy!
          create_audit_event!(ClientChronicleEvent::TELEPHONE_REMOVED, subject: telephone)

          redirect_to(
            sign_com_configuration_telephones_path(ri: params[:ri]),
            notice: t("sign.app.configuration.telephone.destroy.success"),
            status: :see_other,
          )
        end

        private

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            ClientChronicleEvent.find_or_create_by!(id: event_id)
            ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
          end

          ClientChronicle.create!(
            actor_type: "Visitor",
            actor_id: current_visitor.id,
            event_id: event_id,
            subject_id: subject.id.to_s,
            subject_type: subject.class.name,
            occurred_at: Time.current,
          )
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "configuration_telephone"
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
          Outbound::Sms.deliver_later(
            to: visitor_telephone.number,
            title: message,
            body: message,
          )
        end

        def check_telephone_verification_rate_limit!
          cache_key = "rate-limit:telephone_verification:#{request.remote_ip}"
          count = RateLimit.store.increment(cache_key, 1, expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds)
          return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

          Rails.logger.info(
            Jit::LogEvent.format(
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
