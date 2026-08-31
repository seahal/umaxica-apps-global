# typed: false
# frozen_string_literal: true

class TotpWindowConsumer
  Result =
    Data.define(:status, :credential, :otp_at) do
      def accepted? = status == :accepted

      def replay? = status == :replay
    end

  def self.call(credentials:, token:, now: Time.current)
    new(credentials:, token:, now:).call
  end

  def initialize(credentials:, token:, now:)
    @credentials = credentials
    @token = token.to_s
    @now = now
  end

  def call
    credentials.each do |credential|
      otp_at = ROTP::TOTP.new(credential.private_key).verify(token, at: now.to_i)
      next unless otp_at

      return consume(credential, otp_at)
    end

    Result.new(status: :mismatch, credential: nil, otp_at: nil)
  end

  private

  attr_reader :credentials, :token, :now

  def consume(credential, otp_at)
    accepted =
      credential.with_lock do
        stored = credential.last_otp_at
        stored_finite = stored.present? && !(stored.respond_to?(:infinite?) && stored.infinite?)
        next false if stored_finite && stored.to_i >= otp_at.to_i

        credential.update!(last_otp_at: Time.zone.at(otp_at))
        true
      end

    Result.new(
      status: accepted ? :accepted : :replay,
      credential: credential,
      otp_at: otp_at,
    )
  end
end
