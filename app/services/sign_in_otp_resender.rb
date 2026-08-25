# typed: false
# frozen_string_literal: true

# Resends a sign-in OTP. Email is the only supported channel: SMS OTP is not an
# accepted sign-in proof, so no telephone branch exists to be re-enabled.
class SignInOtpResender
  include CommonOtp

  KIND = "email"
  BASE_SECONDS = 30
  EMAIL_CAP_SECONDS = 15.minutes.to_i
  INVALID_RETRY_AFTER = 30
  MAX_HISTORY = 30
  STATUS_ID_CACHE = Concurrent::Map.new

  Response = Struct.new(:status, :resendable, :retry_after, keyword_init: true)

  def initialize(kind:, state:)
    @kind = kind.to_s
    raise ArgumentError, "unsupported sign-in OTP resend kind: #{@kind}" unless @kind == KIND

    @state = state
  end

  def call
    parsed = SignInOtpResendState.parse(@state)
    return invalid_response unless parsed && parsed[:kind] == @kind

    normalized_target = IdentifierBlindIndex.normalize_email(parsed[:target])
    return invalid_response if normalized_target.blank?

    occurrence_body = occurrence_hmac(normalized_target)
    occurrence = EmailOccurrence.find_or_initialize_by(body: occurrence_body)
    issued_timestamps = parse_issued_history(occurrence.memo)

    policy = SignInOtpResendPolicy.new(base_seconds: BASE_SECONDS, cap_seconds: EMAIL_CAP_SECONDS)
    decision = policy.evaluate(issued_timestamps: issued_timestamps)

    unless decision.resendable
      log_blocked!(
        occurrence: occurrence, issued_timestamps: issued_timestamps,
        retry_after: decision.retry_after,
      )
      return Response.new(
        status: :too_many_requests, resendable: false,
        retry_after: decision.retry_after,
      )
    end

    issue_and_send!(normalized_target)

    updated_history = (issued_timestamps + [Time.current]).last(MAX_HISTORY)
    log_issued!(occurrence: occurrence, issued_timestamps: updated_history)

    Response.new(status: :ok, resendable: true, retry_after: 0)
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { service: "otp_resend", kind: @kind })
    invalid_response
  end

  private

  def invalid_response
    Response.new(status: :bad_request, resendable: false, retry_after: INVALID_RETRY_AFTER)
  end

  def occurrence_hmac(normalized_target)
    OccurrenceHmac.digest(kind: @kind, body: normalized_target)
  end

  def parse_issued_history(memo)
    return [] if memo.blank?

    raw = memo.to_s[/issued=([0-9,]+)/, 1]
    return [] if raw.blank?

    raw.split(",").filter_map do |value|
      seconds = Integer(value.to_s, 10)
      Time.zone.at(seconds) if seconds.positive?
    end
  end

  def issue_and_send!(normalized_target)
    records = ClientEmail.with_address(normalized_target)

    return if records.any?(&:locked?)

    records.find_each do |record|
      clear_otp(record)
    rescue StandardError => e
      Rails.error.report(
        e, handled: true, context: {
          service: "otp_resend", action: "clear_otp", record_id: record.id,
        },
      )
    end

    target = records.order(created_at: :asc).first
    unless target
      perform_dummy_otp_generation
      return
    end

    otp_code = generate_otp_for(target)
    OtpAdapter
      .for(surface: :app, channel: :email)
      .deliver(record: target, otp_code: otp_code)
  end

  def log_issued!(occurrence:, issued_timestamps:)
    occurrence.status_id = self.class.email_issued_status_id
    occurrence.memo = build_memo(issued_timestamps: issued_timestamps)
    occurrence.save!
  end

  def log_blocked!(occurrence:, issued_timestamps:, retry_after:)
    occurrence.status_id = self.class.email_blocked_status_id
    occurrence.memo = build_memo(issued_timestamps: issued_timestamps, retry_after: retry_after)
    occurrence.save!
  end

  def build_memo(issued_timestamps:, retry_after: nil)
    values = issued_timestamps.last(MAX_HISTORY).map { |i| epoch_seconds(i) }.join(",")
    memo = "purpose=in issued=#{values}"
    memo += " retry_after=#{Integer(retry_after.to_s, 10)}" if retry_after
    memo[0, 1000]
  end

  def epoch_seconds(value)
    return value.to_i if value.respond_to?(:to_i)

    Integer(value.to_s, 10)
  end

  class << self
    def email_issued_status_id
      status_id_for(EmailOccurrenceStatus, :ACTIVE)
    end

    def email_blocked_status_id
      status_id_for(EmailOccurrenceStatus, :NOTHING)
    end

    private

    def status_id_for(status_class, key)
      STATUS_ID_CACHE.compute_if_absent(status_class) { Concurrent::Map.new }
        .compute_if_absent(key) do
          status_id =
            case status_class.name
            when "EmailOccurrenceStatus"
              { ACTIVE: EmailOccurrenceStatus::ACTIVE, NOTHING: EmailOccurrenceStatus::NOTHING }.fetch(key)
            else
              raise KeyError, "Unsupported occurrence status class: #{status_class.name}"
            end
          status_class.find_or_create_by!(id: status_id).id
        end
    end
  end
end
