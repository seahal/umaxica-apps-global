# typed: false
# frozen_string_literal: true

module Sign
  module EmailRegistrable
    extend ActiveSupport::Concern

    STATE_INIT = "init"
    STATE_EMAIL_CREATED = "email_created"
    STATE_EMAIL_VERIFIED = "email_verified"
    VALID_STATES = [STATE_INIT, STATE_EMAIL_CREATED, STATE_EMAIL_VERIFIED].freeze

    FLOW_REQUIREMENTS = {
      new: STATE_INIT,
      create: STATE_INIT,
      edit: STATE_EMAIL_CREATED,
      update: STATE_EMAIL_CREATED,
      show: STATE_EMAIL_VERIFIED,
      destroy: STATE_EMAIL_VERIFIED,
    }.freeze

    FLOW_PROGRESSIONS = {
      create: STATE_EMAIL_CREATED,
      update: STATE_EMAIL_VERIFIED,
      destroy: STATE_INIT,
    }.freeze

    SESSION_KEY = :sign_up_email_flow_state
    EXISTING_EMAIL_SESSION_KEY = :sign_up_existing_email_id
    EXISTING_EMAIL_SKIP_OTP_SESSION_KEY = :sign_up_existing_email_skip_otp

    included do
      include ::CloudflareTurnstile
      include Common::Redirect
      include Common::Otp

      before_action :enforce_email_flow!
    end

    private

    def enforce_email_flow!
      required_state = FLOW_REQUIREMENTS[action_name.to_sym]
      return unless required_state

      current_state = email_flow_state
      if action_name.to_sym.in?([:new, :create]) && current_state != STATE_INIT
        reset_email_flow!
        return
      end

      return if current_state == required_state

      redirect_flow_violation
    end

    def email_flow_state
      current_state = session[SESSION_KEY]
      current_state = current_state.to_s if current_state.present?
      current_state = STATE_INIT unless VALID_STATES.include?(current_state)
      session[SESSION_KEY] = current_state
    end

    def progress_email_flow!(action)
      next_state = FLOW_PROGRESSIONS[action.to_sym]
      session[SESSION_KEY] = next_state if next_state
    end

    def reset_email_flow!
      session[SESSION_KEY] = STATE_INIT
      session.delete(EXISTING_EMAIL_SESSION_KEY)
      session.delete(EXISTING_EMAIL_SKIP_OTP_SESSION_KEY)
    end

    def redirect_flow_violation
      flash[:alert] = t("sign.app.registration.email.flow.invalid")
      redirect_to(new_sign_app_up_email_path)
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def initiate_email_verification!(email_address, confirm_policy: "1", allow_existing: false)
      return false unless ensure_turnstile!(email_address, confirm_policy)

      build_user_email(email_address, confirm_policy)
      @user_email.user_email_status_id = UserEmailStatus::UNVERIFIED_WITH_SIGN_UP

      @user_email.validate
      existing_email =
        if allow_existing && @user_email.address_digest.present?
          UserEmail.find_by(address_digest: @user_email.address_digest)
        end
      uniqueness_only = email_uniqueness_only_error?(@user_email)

      if allow_existing && existing_email &&
          existing_email.user_email_status_id != UserEmailStatus::UNVERIFIED_WITH_SIGN_UP &&
          (uniqueness_only || @user_email.errors.empty?)
        return dispatch_existing_email_verification!(existing_email)
      end

      has_errors = @user_email.errors.details.except(:user, :user_id).any?

      if has_errors
        return false unless allow_existing && uniqueness_only &&
          existing_email&.user_email_status_id == UserEmailStatus::UNVERIFIED_WITH_SIGN_UP
      end

      if existing_email&.user_email_status_id == UserEmailStatus::UNVERIFIED_WITH_SIGN_UP &&
          existing_email.otp_cooldown_active?
        return :cooldown
      end

      cooldown_active = false
      begin
        UserEmail.transaction do
          # 2. Definitive check inside transaction with row lock
          if existing_email&.user_email_status_id == UserEmailStatus::UNVERIFIED_WITH_SIGN_UP
            locked = UserEmail.lock.find_by(id: existing_email.id)
            if locked&.otp_cooldown_active?
              cooldown_active = true
              raise ActiveRecord::Rollback
            end
          end

          cleanup_pending_signup!
          remove_existing_unverified_emails!
          create_pending_user!

          num = generate_otp_attributes(@user_email)
          @user_email.otp_last_sent_at = Time.current
          @user_email.save!

          send_verification_email(num)
        end
      rescue ActiveRecord::RecordInvalid => e
        @user_email = e.record
        return false
      end

      return :cooldown if cooldown_active

      true
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def complete_email_verification!(id, submitted_code, token = nil)
      @user_email = UserEmail.find_by(public_id: id)

      # Session validation should be done in controller
      # This method assumes valid session

      # Verify token if provided (strict verification)
      if token.present?
        unless @user_email.verify_verification_token(token)
          @user_email.errors.add(:base, t("sign.app.registration.email.update.invalid_token"))
          return false
        end
      end

      result = verify_otp_code(@user_email, submitted_code)

      unless result[:success]
        increment_otp_attempts!(@user_email)
        if @user_email.locked?
          @user_email.destroy!
          @user_email.errors.add(:base, :locked)
          return :locked
        end
        @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
        return false
      end

      begin
        @user_email.transaction do
          clear_otp(@user_email)
          @user_email.user_email_status_id = UserEmailStatus::VERIFIED_WITH_SIGN_UP

          yield(@user_email) if block_given?
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
        # Transaction rolled back
        @user_email.errors.add(:base, e.message) if @user_email.errors.empty?
        return false
      end

      true
    end

    def ensure_turnstile!(email_address, confirm_policy)
      turnstile_result = cloudflare_turnstile_validation
      return true if turnstile_result["success"]

      @user_email = UserEmail.new(raw_address: email_address, confirm_policy: confirm_policy)
      @user_email.errors.add(:base, t("sign.app.registration.email.create.turnstile_validation_failed"))
      false
    end

    def build_user_email(email_address, confirm_policy)
      @user_email = UserEmail.new(raw_address: email_address, confirm_policy: confirm_policy)
    end

    def cleanup_pending_signup!
      pending_user_id = session[:pending_sign_up_user_id]
      return if pending_user_id.blank?

      User.find_by(id: pending_user_id, status_id: UserStatus::UNVERIFIED_WITH_SIGN_UP)&.destroy!
    end

    def remove_existing_unverified_emails!
      return if @user_email.address_digest.blank?

      existing_emails = UserEmail.where(
        address_digest: @user_email.address_digest,
        user_email_status_id: [
          UserEmailStatus::UNVERIFIED_WITH_SIGN_UP,
        ],
      ).to_a

      pending_user_ids = existing_emails.filter_map(&:user_id)
      User.where(id: pending_user_ids).find_each(&:destroy!) if pending_user_ids.any?

      existing_emails.each do |email|
        email.destroy! if email.user_id.blank?
      end
    end

    def create_pending_user!
      @pending_user = User.create!(status_id: UserStatus::UNVERIFIED_WITH_SIGN_UP)
      @user_email.user = @pending_user
      session[:pending_sign_up_user_id] = @pending_user.id
      session[:pending_sign_up_email] = @user_email.address.to_s.downcase
    end

    def dispatch_existing_email_verification!(existing_email)
      @user_email = existing_email
      session[EXISTING_EMAIL_SESSION_KEY] = @user_email.id
      session[EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = true
      true
    end

    def send_verification_email(otp_number)
      token = @user_email.generate_verification_token

      Email::App::RegistrationMailer.with(
        hotp_token: otp_number,
        email_address: @user_email.address,
        verification_token: token,
        public_id: @user_email.public_id,
      ).create.deliver_later
    end

    def email_uniqueness_only_error?(user_email)
      # ignore :user and :user_id error
      errors_to_check = user_email.errors.details.except(:user, :user_id)
      return false if errors_to_check.empty?

      # Fields that can have uniqueness errors
      uniqueness_fields = %i(address raw_address address_bidx address_digest)

      # Check if all errors are :taken errors on the uniqueness fields
      errors_to_check.each do |field, errors|
        return false unless uniqueness_fields.include?(field)
        return false unless errors.all? { |error| error[:error] == :taken }
      end

      # Ensure at least one uniqueness error is present
      user_email.errors.details.any?
    end
  end
end
