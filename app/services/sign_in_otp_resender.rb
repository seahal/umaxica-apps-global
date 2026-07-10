# typed: false
# frozen_string_literal: true

class SignInOtpResender
  include CommonOtp

  BASE_SECONDS = 30
  EMAIL_CAP_SECONDS = 15.minutes.to_i
  TELEPHONE_CAP_SECONDS = 60.minutes.to_i
  INVALID_RETRY_AFTER = 30
  MAX_HISTORY = 30
  STATUS_ID_CACHE = Concurrent::Map.new

  Response = Struct.new(:status, :resendable, :retry_after, keyword_init: true)

  def initialize(kind:, state:)
    @kind = kind.to_s
    @state = state
  end

  def call
    parsed = SignInOtpResendState.parse(@state)
    return invalid_response unless parsed && parsed[:kind] == @kind

    normalized_target = normalize_target(parsed[:target])
    return invalid_response if normalized_target.blank?

    occurrence_body = occurrence_hmac(normalized_target)
    occurrence = occurrence_model.find_or_initialize_by(body: occurrence_body)
    issued_timestamps = parse_issued_history(occurrence.memo)

    policy = SignInOtpResendPolicy.new(base_seconds: BASE_SECONDS, cap_seconds: cap_seconds)
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

  def normalize_target(raw_value)
    case @kind
    when "email"
      IdentifierBlindIndex.normalize_email(raw_value)
    when "telephone"
      normalized = IdentifierBlindIndex.normalize_telephone(raw_value)
      normalized if normalized&.match?(/\A\+[0-9]+\z/)
    end
  end

  def occurrence_hmac(normalized_target)
    OccurrenceHmac.digest(kind: @kind, body: normalized_target)
  end

  def cap_seconds
    (@kind == "telephone") ? TELEPHONE_CAP_SECONDS : EMAIL_CAP_SECONDS
  end

  def occurrence_model
    (@kind == "telephone") ? TelephoneOccurrence : EmailOccurrence
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
    records = target_records(normalized_target)

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
      .for(surface: :app, channel: @kind.to_sym)
      .deliver(record: target, otp_code: otp_code)
  end

  def target_records(normalized_target)
    return ClientTelephone.none if @kind == "telephone" && normalized_target.blank?
    return ClientEmail.none if @kind == "email" && normalized_target.blank?

    if @kind == "telephone"
      ClientTelephone.with_number(normalized_target)
    else
      ClientEmail.with_address(normalized_target)
    end
  end

  def issued_status_id
    if @kind == "telephone"
      self.class.telephone_issued_status_id
    else
      self.class.email_issued_status_id
    end
  end

  def blocked_status_id
    if @kind == "telephone"
      self.class.telephone_blocked_status_id
    else
      self.class.email_blocked_status_id
    end
  end

  def log_issued!(occurrence:, issued_timestamps:)
    occurrence.status_id = issued_status_id
    occurrence.memo = build_memo(issued_timestamps: issued_timestamps)
    occurrence.save!
  end

  def log_blocked!(occurrence:, issued_timestamps:, retry_after:)
    occurrence.status_id = blocked_status_id
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

    def telephone_issued_status_id
      status_id_for(TelephoneOccurrenceStatus, :ACTIVE)
    end

    def telephone_blocked_status_id
      status_id_for(TelephoneOccurrenceStatus, :NOTHING)
    end

    private

    def status_id_for(status_class, key)
      STATUS_ID_CACHE.compute_if_absent(status_class) { Concurrent::Map.new }
        .compute_if_absent(key) do
          status_id =
            case status_class.name
            when "EmailOccurrenceStatus"
              { ACTIVE: EmailOccurrenceStatus::ACTIVE, NOTHING: EmailOccurrenceStatus::NOTHING }.fetch(key)
            when "TelephoneOccurrenceStatus"
              { ACTIVE: TelephoneOccurrenceStatus::ACTIVE,
                NOTHING: TelephoneOccurrenceStatus::NOTHING, }.fetch(key)
            else
              raise KeyError, "Unsupported occurrence status class: #{status_class.name}"
            end
          status_class.find_or_create_by!(id: status_id).id
        end
    end
  end
end
