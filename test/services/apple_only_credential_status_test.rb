# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class AppleOnlyCredentialStatusTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  fixtures :client_statuses

  test "identifies an active Apple identity as the only AAL1 credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "n#{SecureRandom.hex(8)}")
    create_active_external_identity(client: client, provider: "apple")

    assert AppleOnlyCredentialStatus.call(client)
  end

  test "does not warn when Google is also an active AAL1 credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "n#{SecureRandom.hex(8)}")
    create_active_external_identity(client: client, provider: "apple")
    create_active_external_identity(client: client, provider: "google")

    assert_not AppleOnlyCredentialStatus.call(client)
  end
end
