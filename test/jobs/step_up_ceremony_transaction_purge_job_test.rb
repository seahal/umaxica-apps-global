# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUpCeremonyTransactionPurgeJobTest < ActiveJob::TestCase
  test "calls purger service with custom batch size" do
    mock_purger = Minitest::Mock.new
    mock_purger.expect(:call, true)

    # Note: verify that new receives batch_size: 100
    mock_new =
      lambda { |batch_size:|
        assert_equal 100, batch_size
        mock_purger
      }

    IdentityStepUpCeremonyTransactionPurger.stub(:new, mock_new) do
      StepUpCeremonyTransactionPurgeJob.perform_now(batch_size: 100)
    end

    mock_purger.verify
  end
end
