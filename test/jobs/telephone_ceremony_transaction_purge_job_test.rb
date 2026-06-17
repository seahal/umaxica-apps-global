# typed: false
# frozen_string_literal: true

require "test_helper"

class TelephoneCeremonyTransactionPurgeJobTest < ActiveJob::TestCase
  test "calls purger service with default batch size" do
    mock_purger = Minitest::Mock.new
    mock_purger.expect(:call, nil)

    mock_new =
      lambda { |batch_size:|
        assert_equal 500, batch_size
        mock_purger
      }

    IdentityTelephoneCeremonyTransactionPurger.stub(:new, mock_new) do
      TelephoneCeremonyTransactionPurgeJob.perform_now
    end

    mock_purger.verify
  end

  test "calls purger service with custom batch size" do
    mock_purger = Minitest::Mock.new
    mock_purger.expect(:call, nil)

    mock_new =
      lambda { |batch_size:|
        assert_equal 100, batch_size
        mock_purger
      }

    IdentityTelephoneCeremonyTransactionPurger.stub(:new, mock_new) do
      TelephoneCeremonyTransactionPurgeJob.perform_now(batch_size: 100)
    end

    mock_purger.verify
  end
end
