# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      class TelephonesController < ApplicationController
        include CloudflareTurnstile
        include Common::Redirect
        include Common::Otp

        guest_only! status: :unauthorized
        prepend_before_action :reject_logged_in_session, only: %i(new create)

        def new
          @visitor_telephone = VisitorTelephone.new
          session[:visitor_telephone_registration] = nil
        end

        def edit
          @visitor_telephone = VisitorTelephone.find_by(public_id: params["id"])
          return if valid_telephone_session?

          redirect_to(
            new_sign_com_up_telephone_path,
            notice: t("sign.com.registration.telephone.edit.session_expired"),
          )
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def create
          telephone_params = params.fetch(:visitor_telephone, {}).permit(
            :raw_number, :number, :confirm_policy, :confirm_using_mfa,
          )
          if telephone_params.blank?
            @visitor_telephone = VisitorTelephone.new
            @visitor_telephone.errors.add(:raw_number, :blank)
            render :new, status: :unprocessable_content
            return
          end

          @visitor_telephone = VisitorTelephone.new(telephone_params || {})

          res = cloudflare_turnstile_validation

          unless res["success"]
            @visitor_telephone.errors.add(
              :base,
              t("sign.app.registration.telephone.create.turnstile_validation_failed"),
            )
            render :new, status: :unprocessable_content
            return
          end

          @visitor_telephone.validate

          existing_telephone = find_existing_telephone_by_digest
          uniqueness_only = telephone_uniqueness_only_error?(@visitor_telephone)
          has_errors = @visitor_telephone.errors.details.except(:visitor, :visitor_id).any?

          if has_errors && !uniqueness_only
            render :new, status: :unprocessable_content
            return
          end

          if existing_telephone &&
              existing_telephone.visitor_telephone_status_id != VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
            if existing_telephone.locked?
              render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
              return
            end

            dispatch_existing_telephone_verification!(existing_telephone)
            return
          end

          if existing_telephone&.locked?
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
            return
          end

          if existing_telephone&.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
              existing_telephone.reregistration_window_active?
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
            return
          end

          VisitorTelephone.transaction do
            cleanup_pending_visitor_signup!

            locked_existing = VisitorTelephone.lock.find_by(id: existing_telephone.id) if existing_telephone
            if locked_existing&.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
                locked_existing.reregistration_window_active?
              render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
              raise ActiveRecord::Rollback
            end

            if locked_existing&.locked?
              render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
              raise ActiveRecord::Rollback
            end

            remove_existing_unverified_telephones!

            pending_visitor =
              Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
            @visitor_telephone.visitor = pending_visitor
            @visitor_telephone.visitor_telephone_status_id = VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP

            otp_number = generate_otp_attributes(@visitor_telephone)
            @visitor_telephone.otp_last_sent_at = Time.current if @visitor_telephone.respond_to?(:otp_last_sent_at=)
            @visitor_telephone.save!

            session[:visitor_telephone_registration] = @visitor_telephone.public_id

            SmsDeliveryJob.perform_later(
              to: @visitor_telephone.number,
              message: "PassCode => #{otp_number}",
              subject: "PassCode => #{otp_number}",
            )

            redirect_to(
              edit_sign_com_up_telephone_path(
                id: @visitor_telephone.public_id,
                ri: params[:ri],
              ),
            )
          end
        rescue ActiveRecord::RecordInvalid
          render :new, status: :unprocessable_content
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def update
          @visitor_telephone = VisitorTelephone.find_by(public_id: params["id"])
          unless @visitor_telephone
            return redirect_to(new_sign_com_up_telephone_path)
          end

          return redirect_to(new_sign_com_up_telephone_path) unless valid_telephone_session?

          submitted_code = params.dig("visitor_telephone", "pass_code")
          if submitted_code.blank?
            @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
            render :edit, status: :unprocessable_content
            return
          end

          result = verify_otp_code(@visitor_telephone, submitted_code)
          unless result[:success]
            increment_otp_attempts!(@visitor_telephone)
            if @visitor_telephone.locked?
              session[:visitor_telephone_registration] = nil
              redirect_to(
                new_sign_com_up_telephone_path(ri: params[:ri]),
                alert: t("sign.app.registration.telephone.update.attempts_exceeded"),
              )
              return
            end

            @visitor_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
            render :edit, status: :unprocessable_content
            return
          end

          visitor = @visitor_telephone.visitor
          clear_otp(@visitor_telephone)
          @visitor_telephone.update!(visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP)
          visitor.create_client_account! unless visitor&.client_account
          create_signup_audit!(visitor) if visitor
          log_in(
            visitor,
            record_login_audit: true,
            audit_context: { auth_method: "telephone" },
          ) if visitor
          redirect_to(root_path, notice: t("sign.com.registration.telephone.success"))
        end

        private

        def valid_telephone_session?
          session[:visitor_telephone_registration] == @visitor_telephone.public_id
        end

        def cleanup_pending_visitor_signup!
          pending_public_id = session[:visitor_telephone_registration]
          return if pending_public_id.blank?

          pending_telephone = VisitorTelephone.find_by(public_id: pending_public_id)
          return unless pending_telephone

          pending_visitor = pending_telephone.visitor
          pending_telephone.destroy!
          pending_visitor.destroy! if pending_visitor&.status_id == VisitorStatus::ACTIVE
        end

        def remove_existing_unverified_telephones!
          return if @visitor_telephone.number_digest.blank?

          VisitorTelephone.where(
            number_digest: @visitor_telephone.number_digest,
            visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
          ).find_each(&:destroy!)
        end

        def telephone_uniqueness_only_error?(visitor_telephone)
          errors_to_check = visitor_telephone.errors.details.except(:visitor, :visitor_id)
          return false if errors_to_check.empty?

          uniqueness_fields = %i(number raw_number number_digest)
          errors_to_check.each do |field, errors|
            return false unless uniqueness_fields.include?(field)
            return false unless errors.all? { |error| error[:error] == :taken }
          end

          visitor_telephone.errors.details.any?
        end

        def find_existing_telephone_by_digest
          return nil if @visitor_telephone.number_digest.blank?

          VisitorTelephone.find_by(number_digest: @visitor_telephone.number_digest)
        end

        def dispatch_existing_telephone_verification!(existing_telephone)
          @visitor_telephone = existing_telephone
          otp_number = generate_otp_for(@visitor_telephone)
          @visitor_telephone.update!(otp_last_sent_at: Time.current) if @visitor_telephone.respond_to?(:otp_last_sent_at=)

          session[:visitor_telephone_registration] = @visitor_telephone.public_id

          SmsDeliveryJob.perform_later(
            to: @visitor_telephone.number,
            message: "PassCode => #{otp_number}",
            subject: "PassCode => #{otp_number}",
          )

          redirect_to(
            edit_sign_com_up_telephone_path(
              id: @visitor_telephone.public_id,
              ri: params[:ri],
            ),
          )
        end

        def create_signup_audit!(visitor)
          event_id = UserChronicleEvent::SIGNED_UP_WITH_TELEPHONE

          ChronicleRecord.connected_to(role: :writing) do
            UserChronicleEvent.find_or_create_by!(id: event_id)
            UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
          end

          UserChronicle.create!(
            actor_type: "Visitor",
            actor_id: visitor.id,
            event_id: event_id,
            level_id: UserChronicleLevel::NOTHING,
            subject_id: visitor.id.to_s,
            subject_type: "Visitor",
          )
        end
      end
    end
  end
end
