# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class StepUpCeremonyTransactionPurgeJobTest < ActiveJob::TestCase
  test "calls purger service with custom batch size" do
    call_count = 0

    stub_new =
      lambda { |batch_size:|
        assert_equal 100, batch_size
        -> { call_count += 1 }
      }

    IdentityStepUpCeremonyTransactionPurger.stub(:new, stub_new) do
      StepUpCeremonyTransactionPurgeJob.perform_now(batch_size: 100)
    end

    assert_equal 1, call_count
  end
end
