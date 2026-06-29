# frozen_string_literal: true

require "test_helper"

class RefreshTokenConcurrencyTest < ActiveSupport::TestCase
  test "concurrent refresh attempts cannot both rotate the same client token" do
    user = create_verified_user_with_email(email_address: "refresh-race-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    refresh = token.rotate_refresh_token!
    digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(refresh).last)

    results = rotate_concurrently(ClientToken, digest)

    assert_equal 2, results.size
    assert_equal 1, results.count { |result| result.fetch(:status) == :rotated }, results.inspect
    assert_equal 1, results.count { |result| result.fetch(:status).in?(%i(replay invalid)) }, results.inspect

    family = ClientToken.where(refresh_token_family_id: token.refresh_token_family_id)

    assert_equal 2, family.count
    assert_equal 1, family.where(rotated_at: nil).count
    assert_predicate token.reload.rotated_at, :present?
  end

  private

  def rotate_concurrently(token_class, digest)
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    threads =
      2.times.map do
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            release.pop
            result = token_class.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)
            results << { status: result.fetch(:status), token_id: result[:token]&.id }
          rescue StandardError => e
            results << { status: :error, error: "#{e.class}: #{e.message}" }
          end
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)
    2.times.map { results.pop }
  end
  private

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!

    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end
end
