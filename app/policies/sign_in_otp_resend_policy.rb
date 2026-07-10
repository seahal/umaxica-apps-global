# typed: false
# frozen_string_literal: true

class SignInOtpResendPolicy
  Result = Struct.new(:resendable, :retry_after, :n5m, :cooldown, :last_issued_at, keyword_init: true)

  def initialize(base_seconds:, cap_seconds:)
    @base_seconds = base_seconds
    @cap_seconds = cap_seconds
  end

  def evaluate(issued_timestamps:, now: Time.current)
    window_start = now - 5.minutes
    recent_issued = issued_timestamps.select { |value| value >= window_start }
    recent_issued.sort!
    n5m = recent_issued.length
    cooldown = [@base_seconds * (2**[n5m - 1, 0].max), @cap_seconds].min
    last_issued_at = recent_issued.last

    retry_after =
      if last_issued_at.present?
        [((last_issued_at + cooldown) - now), 0].max.ceil
      else
        0
      end

    Result.new(
      resendable: retry_after.zero?,
      retry_after: retry_after,
      n5m: n5m,
      cooldown: cooldown,
      last_issued_at: last_issued_at,
    )
  end
end
