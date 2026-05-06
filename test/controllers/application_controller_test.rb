# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActiveSupport::TestCase
  test "uses header_or_legacy_token csrf verification" do
    assert_equal :header_or_legacy_token, ApplicationController.forgery_protection_verification_strategy
  end

  test "uses no trusted origins by default" do
    assert_empty ApplicationController.forgery_protection_trusted_origins
  end
end
