# typed: false
# frozen_string_literal: true

require "test_helper"

class TotpCeremonyTransactionPurgeJobTest < ActiveJob::TestCase
  test "calls purger service" do
    mock_purger = Minitest::Mock.new
    mock_purger.expect(:call, true)

    IdentityTotpCeremonyTransactionPurger.stub(:new, mock_purger) do
      TotpCeremonyTransactionPurgeJob.perform_now
    end

    mock_purger.verify
  end
end
