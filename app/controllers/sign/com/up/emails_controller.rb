# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Up
      class EmailsController < ApplicationController
        include ::CloudflareTurnstile
        include Common::Redirect
        include Common::Otp

        SESSION_KEY = :sign_com_up_email_flow_state
        EXISTING_EMAIL_SESSION_KEY = :sign_com_up_existing_customer_email_id
        EXISTING_EMAIL_SKIP_OTP_SESSION_KEY = :sign_com_up_existing_customer_email_skip_otp
        PENDING_CUSTOMER_ID_SESSION_KEY = :sign_com_up_pending_customer_id

        guest_only! message: I18n.t("sign.app.registration.email.already_logged_in")

        before_action :enforce_email_flow!

        def new
          @user_email = CustomerEmail.new
        end

        def edit
          @user_email = CustomerEmail.find_by(public_id: params["id"])
          if @user_email.blank?
            reset_email_flow!
            redirect_to(
              new_sign_com_up_email_path(ri: params[:ri]),
              notice: t("sign.app.registration.email.edit.not_found"),
            )
            return
          end

          return if valid_email_session?

          reset_email_flow!
          flash[:notice] = t("sign.app.registration.email.edit.session_expired")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def create
          email_params = params.expect(user_email: %i(raw_address address confirm_policy))
          email_address = email_params[:raw_address] || email_params[:address]

          unless cloudflare_turnstile_validation["success"]
            @user_email = CustomerEmail.new(address: email_address)
            @user_email.errors.add(
              :base,
              t("session_limit.turnstile_failed"),
            )
            render :new, status: :unprocessable_content
            return
          end

          result = initiate_customer_email_verification!(email_address, confirm_policy: email_params[:confirm_policy])
          if result == :cooldown
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
            return
          end

          unless result
            render :new, status: :unprocessable_content
            return
          end

          progress_email_flow!(:create)
          flash[:notice] = t("sign.app.registration.email.create.verification_code_sent")
          redirect_to(edit_sign_com_up_email_path(@user_email, ri: params[:ri], rd: sanitized_rd_param))
        end

        def update
          @user_email = CustomerEmail.find_by(public_id: params["id"])
          return redirect_invalid_session unless valid_email_session?
          return render_code_required if params.dig("user_email", "pass_code").blank?

          submitted_code = params.dig("user_email", "pass_code")
          result =
            existing_signup_email_flow? ? handle_existing_email_verification(submitted_code) :
                                           complete_customer_email_verification!(submitted_code)
          return if result == :redirected
          return handle_locked_result if result == :locked
          return render :edit, status: :unprocessable_content unless result

          progress_email_flow!(:update)
          create_welcome_bulletin!(current_resource)
          if issue_bulletin!
            redirect_to(
              sign_com_in_bulletin_path(rd: params[:rd], ri: params[:ri]),
              notice: t("sign.app.registration.email.update.success"),
            )
          else
            safe_redirect_to_rd_or_default!(params[:rd], default_path: sign_com_configuration_path(ri: params[:ri]))
          end
        end

        private

        def enforce_email_flow!
          requirements = { new: "init", create: "init", edit: "email_created", update: "email_created" }
          required = requirements[action_name.to_sym]
          return unless required

          current = email_flow_state
          if %i(new create).include?(action_name.to_sym) && current != "init"
            reset_email_flow!
            return
          end
          return if current == required

          flash[:alert] = t("sign.app.registration.email.flow.invalid")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def email_flow_state
          state = session[SESSION_KEY].to_s
          state = "init" unless %w(init email_created email_verified).include?(state)
          session[SESSION_KEY] = state
        end

        def progress_email_flow!(action)
          next_state = { create: "email_created", update: "email_verified" }[action.to_sym]
          session[SESSION_KEY] = next_state if next_state
        end

        def reset_email_flow!
          session[SESSION_KEY] = "init"
          session.delete(EXISTING_EMAIL_SESSION_KEY)
          session.delete(EXISTING_EMAIL_SKIP_OTP_SESSION_KEY)
          session.delete(PENDING_CUSTOMER_ID_SESSION_KEY)
        end

        def redirect_invalid_session
          reset_email_flow!
          flash[:notice] = t("sign.app.registration.email.edit.session_expired")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def render_code_required
          @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.code_required"))
          render :edit, status: :unprocessable_content
        end

        def handle_locked_result
          reset_email_flow!
          flash[:alert] = t("sign.app.registration.email.update.attempts_exceeded")
          redirect_to(new_sign_com_up_email_path(ri: params[:ri]))
        end

        def valid_email_session?
          return false if @user_email.blank?

          if existing_signup_email_flow?
            return false unless Integer(session_existing_email_id.to_s, 10) == @user_email.id

            existing_signup_skip_otp? || !@user_email.otp_expired?
          else
            return false if @user_email.otp_expired?

            @user_email.customer_email_status_id == CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP
          end
        end

        def existing_signup_email_flow?
          session_existing_email_id.present?
        end

        def session_existing_email_id
          session[EXISTING_EMAIL_SESSION_KEY]
        end

        def existing_signup_skip_otp?
          session[EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] == true
        end

        def initiate_customer_email_verification!(email_address, confirm_policy: "1")
          @user_email = CustomerEmail.new(raw_address: email_address, confirm_policy: confirm_policy)
          @user_email.customer_email_status_id = CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP
          @user_email.validate

          existing_email =
            @user_email.address_digest.present? ?
              CustomerEmail.find_by(address_digest: @user_email.address_digest) : nil
          uniqueness_only = customer_email_uniqueness_only_error?(@user_email)

          if existing_email &&
              existing_email.customer_email_status_id != CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP &&
              (uniqueness_only || @user_email.errors.empty?)
            @user_email = existing_email
            session[EXISTING_EMAIL_SESSION_KEY] = @user_email.id
            session[EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = true
            return true
          end

          return :cooldown if existing_email&.customer_email_status_id ==
            CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP && existing_email.otp_cooldown_active?

          return false if @user_email.errors.details.except(:customer, :customer_id).any? && !uniqueness_only

          CustomerEmail.transaction do
            cleanup_pending_customer_signup!
            remove_existing_unverified_customer_emails!
            pending_customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
            session[PENDING_CUSTOMER_ID_SESSION_KEY] = pending_customer.id
            @user_email.customer = pending_customer
            otp_number = generate_otp_attributes(@user_email)
            @user_email.otp_last_sent_at = Time.current
            @user_email.save!
            token = @user_email.generate_verification_token
            Email::App::RegistrationMailer.with(
              hotp_token: otp_number, email_address: @user_email.address,
              verification_token: token, public_id: @user_email.public_id,
            ).create.deliver_later
          end

          true
        rescue ActiveRecord::RecordInvalid => e
          @user_email = e.record if e.record.is_a?(CustomerEmail)
          false
        end

        def complete_customer_email_verification!(submitted_code)
          result = verify_otp_code(@user_email, submitted_code)
          unless result[:success]
            increment_otp_attempts!(@user_email)
            if @user_email.locked?
              reset_email_flow!
              return :locked
            end
            @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
            return false
          end

          CustomerEmail.transaction do
            clear_otp(@user_email)
            @user_email.update!(customer_email_status_id: CustomerEmailStatus::VERIFIED_WITH_SIGN_UP)
            customer = @user_email.customer
            create_signup_audit!(customer)
            log_in(customer, record_login_audit: false)
          end

          true
        end

        def handle_existing_email_verification(submitted_code)
          if existing_signup_skip_otp?
            reset_email_flow!
            redirect_to(
              new_sign_com_in_path(ri: params[:ri]),
              notice: t("sign.app.registration.email.update.sign_in_required"),
            )
            return :redirected
          end

          result = verify_otp_code(@user_email, submitted_code)
          unless result[:success]
            increment_otp_attempts!(@user_email)
            if @user_email.locked?
              reset_email_flow!
              return :locked
            end
            @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
            return false
          end

          clear_otp(@user_email)
          reset_email_flow!
          session.delete(EXISTING_EMAIL_SESSION_KEY)
          redirect_to(
            new_sign_com_in_path(ri: params[:ri]),
            notice: t("sign.app.registration.email.update.sign_in_required"),
          )
          :redirected
        end

        def cleanup_pending_customer_signup!
          pending_customer_id = session[PENDING_CUSTOMER_ID_SESSION_KEY]
          return if pending_customer_id.blank?

          Customer.find_by(id: pending_customer_id)&.destroy!
        end

        def remove_existing_unverified_customer_emails!
          return if @user_email.address_digest.blank?

          existing_emails = CustomerEmail.where(address_digest: @user_email.address_digest, customer_email_status_id: [CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP]).to_a
          pending_customer_ids = existing_emails.filter_map(&:customer_id)
          Customer.where(id: pending_customer_ids).find_each(&:destroy!) if pending_customer_ids.any?
          existing_emails.each { |email| email.destroy! if email.customer_id.blank? }
        end

        def customer_email_uniqueness_only_error?(customer_email)
          errors_to_check = customer_email.errors.details.except(:customer, :customer_id)
          return false if errors_to_check.empty?

          uniqueness_fields = %i(address raw_address address_bidx address_digest)
          errors_to_check.each do |field, errors|
            return false unless uniqueness_fields.include?(field)
            return false unless errors.all? { |error| error[:error] == :taken }
          end
          customer_email.errors.details.any?
        end

        def create_signup_audit!(customer)
          event_id = UserChronicleEvent::SIGNED_UP_WITH_EMAIL
          ChronicleRecord.connected_to(role: :writing) do
            UserChronicleEvent.find_or_create_by!(id: event_id)
            UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
            UserChronicle.create!(
              actor_type: "Customer", actor_id: customer.id, event_id: event_id,
              subject_id: customer.id.to_s, subject_type: "Customer",
            )
          end
        end

        def sanitized_rd_param
          return if params[:rd].blank?

          decoded_url = Base64.urlsafe_decode64(params[:rd])
          safe_path = safe_internal_path(decoded_url)
          Base64.urlsafe_encode64(safe_path) if safe_path
        rescue ArgumentError, URI::InvalidURIError
          nil
        end
      end
    end
  end
end
