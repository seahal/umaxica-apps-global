# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class TotpCeremonyTransactionPurgeJobTest < ActiveJob::TestCase
  test "calls purger service" do
    call_count = 0

    stub_new =
      -> {
        -> { call_count += 1 }
      }

    IdentityTotpCeremonyTransactionPurger.stub(:new, stub_new) do
      TotpCeremonyTransactionPurgeJob.perform_now
    end

    assert_equal 1, call_count
  end
end
