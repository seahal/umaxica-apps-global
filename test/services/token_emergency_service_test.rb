# typed: false
# frozen_string_literal: true

require "test_helper"

class TokenEmergencyServiceTest < ActiveSupport::TestCase
  test "call! raises NotImplementedError" do
    error = assert_raises(NotImplementedError) { TokenEmergencyService.call! }

    assert_equal "TokenEmergencyService.call! is not implemented yet", error.message
  end
end
