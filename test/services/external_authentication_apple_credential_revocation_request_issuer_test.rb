# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleCredentialRevocationRequestIssuerTest < ActiveJob::TestCase
  fixtures :client_statuses

  test "enqueues a durable request only after a refresh token is available" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "i#{SecureRandom.hex(8)}")

    assert_enqueued_with(job: AppleCredentialRevocationJob) do
      request = ExternalAuthenticationAppleCredentialRevocationRequestIssuer.call(
        client: client,
        refresh_token: "apple-refresh-token",
        reason: "unlink",
      )

      assert_predicate request, :dispatchable?
    end
  end

  test "records an unavailable credential without enqueuing a provider call" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "i#{SecureRandom.hex(8)}")

    assert_no_enqueued_jobs do
      request = ExternalAuthenticationAppleCredentialRevocationRequestIssuer.call(
        client: client,
        refresh_token: "",
        reason: "withdrawal",
      )

      assert_equal "expired", request.status
      assert_equal "credential_unavailable", request.last_failure_code
    end
  end
end
