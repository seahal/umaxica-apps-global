# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleCredentialRevocationJobTest < ActiveJob::TestCase
  fixtures :client_statuses

  class FakeRevocationAdapter
    def initialize(result)
      @result = result
    end

    def call(refresh_token:)
      raise ArgumentError, "refresh token was not supplied" if refresh_token.blank?

      @result
    end
  end

  test "completes and crypto-shreds a successful request" do
    request = create_request
    result = ExternalAuthentication::CredentialRevocationResult.new(status: :revoked_or_already_invalid)

    adapter = FakeRevocationAdapter.new(result)
    ExternalAuthentication::AppleCredentialRevocationAdapter.stub(:from_credentials, -> { adapter }) do
      AppleCredentialRevocationJob.perform_now(request.public_id)
    end

    assert_equal "completed", request.reload.status
    assert_equal "", request.refresh_token
  end

  test "re-enqueues a transient provider failure with bounded backoff" do
    request = create_request
    result = ExternalAuthentication::CredentialRevocationResult.new(
      status: :failed,
      code: :provider_unavailable,
    )

    ExternalAuthentication::AppleCredentialRevocationAdapter.stub(
      :from_credentials,
      -> { FakeRevocationAdapter.new(result) },
    ) do
      assert_enqueued_with(job: AppleCredentialRevocationJob, args: [request.public_id]) do
        AppleCredentialRevocationJob.perform_now(request.public_id)
      end
    end

    assert_equal "retrying", request.reload.status
    assert_equal 1, request.retry_count
    assert_equal "provider_unavailable", request.last_failure_code
  end

  test "crypto-shreds a permanent provider rejection without retrying" do
    request = create_request
    result = ExternalAuthentication::CredentialRevocationResult.new(
      status: :failed,
      code: :provider_rejected,
    )

    ExternalAuthentication::AppleCredentialRevocationAdapter.stub(
      :from_credentials,
      -> { FakeRevocationAdapter.new(result) },
    ) do
      assert_no_enqueued_jobs do
        AppleCredentialRevocationJob.perform_now(request.public_id)
      end
    end

    assert_equal "expired", request.reload.status
    assert_equal "provider_rejected", request.last_failure_code
    assert_equal "", request.refresh_token
  end

  private

  def create_request
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "job_#{SecureRandom.hex(8)}")
    ClientAppleCredentialRevocation.create!(client: client, refresh_token: "refresh-token", reason: "unlink")
  end
end
