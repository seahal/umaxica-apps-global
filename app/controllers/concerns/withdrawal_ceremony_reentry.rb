# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyReentry
  extend ActiveSupport::Concern
  include CommonOtp
  include EmailValidation
  include WithdrawalCeremonyAuthentication

  REENTRY_SESSION_KEY = :withdrawal_ceremony_reentry
  GENERIC_MESSAGE = "If an account can continue withdrawal procedures for the information entered, the next step is available here."

  included do
    helper_method :withdrawal_reentry_generic_message
  end

  def new
    @email_record = identity_email_model.new
    @reentry_state = withdrawal_reentry_state
  end

  def create
    return verify_withdrawal_reentry_otp if params[:pass_code].present?

    start_withdrawal_reentry_otp
  end

  private

  def start_withdrawal_reentry_otp
    normalized_address = validate_and_normalize_email(withdrawal_reentry_address)
    email = normalized_address.present? ? find_email_with_timing_protection(normalized_address) : nil
    subject = withdrawal_subject_from_email(email)

    if withdrawal_reentry_subject_eligible?(subject) && !email.locked? && !otp_request_rate_limited?(email)
      otp_code = generate_otp_for(email)
      OtpAdapter.for(surface: withdrawal_reentry_surface, channel: :email).deliver(record: email, otp_code: otp_code)
      session[REENTRY_SESSION_KEY] = {
        "email_public_id" => email.public_id,
        "dummy" => false,
        "expires_at" => CommonOtp::OTP_EXPIRATION_MINUTES.minutes.from_now.to_i,
      }
    else
      perform_dummy_otp_generation
      session[REENTRY_SESSION_KEY] = {
        "dummy" => true,
        "expires_at" => CommonOtp::OTP_EXPIRATION_MINUTES.minutes.from_now.to_i,
      }
    end

    @generic_message = withdrawal_reentry_generic_message
    @reentry_state = withdrawal_reentry_state
    @email_record = identity_email_model.new(address: withdrawal_reentry_address)
    render :new, status: :ok
  end

  def verify_withdrawal_reentry_otp
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    state = withdrawal_reentry_state
    return render_withdrawal_reentry_invalid_code(start_time) if state.blank? || state["expires_at"].to_i <= Time.current.to_i
    return render_withdrawal_reentry_invalid_code(start_time) if state["dummy"]

    email = identity_email_model.find_by(public_id: state["email_public_id"].to_s)
    subject = withdrawal_subject_from_email(email)
    unless email && withdrawal_reentry_subject_eligible?(subject)
      return render_withdrawal_reentry_invalid_code(start_time)
    end

    result = verify_otp_code(email, params[:pass_code])
    unless result[:success]
      increment_otp_attempts!(email)
      return render_withdrawal_reentry_invalid_code(start_time)
    end

    clear_otp(email)
    session.delete(REENTRY_SESSION_KEY)
    ensure_min_elapsed(start_time)
    issue_withdrawal_ceremony!(subject: subject, purpose: "status")
    safe_redirect_to(withdrawal_edit_path, fallback: withdrawal_new_path, status: :see_other)
  end

  def render_withdrawal_reentry_invalid_code(start_time)
    verify_dummy_otp(params[:pass_code].to_s)
    ensure_min_elapsed(start_time)
    @generic_message = withdrawal_reentry_generic_message
    @reentry_state = withdrawal_reentry_state
    @email_record = identity_email_model.new(address: withdrawal_reentry_address)
    render :new, status: :unprocessable_content
  end

  def withdrawal_reentry_state
    data = session[REENTRY_SESSION_KEY]
    return nil unless data.is_a?(Hash)
    return session.delete(REENTRY_SESSION_KEY) if data["expires_at"].to_i <= Time.current.to_i

    data
  end

  def withdrawal_reentry_address
    params.dig(:withdrawal_reentry, :address).to_s
  end

  def withdrawal_reentry_generic_message
    GENERIC_MESSAGE
  end

  def otp_request_rate_limited?(email)
    email.respond_to?(:otp_cooldown_active?) && email.otp_cooldown_active?
  end

  def withdrawal_reentry_subject_eligible?(subject)
    return false if subject.blank?
    return false unless subject.respond_to?(:withdrawal_in_progress?)
    return false if subject.active?

    subject.withdrawal_in_progress? || subject.terminated?
  end
end
