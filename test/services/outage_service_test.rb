# typed: false
# frozen_string_literal: true

require "test_helper"

class OutageServiceTest < ActiveSupport::TestCase
  test "update! raises NotImplementedError" do
    assert_raises(NotImplementedError, "OutageService.update! is not implemented yet") do
      OutageService.update!
    end
  end
end
