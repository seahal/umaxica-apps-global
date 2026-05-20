# typed: false
# frozen_string_literal: true

require "test_helper"

module SocialAuth
  class StepUpRequiredErrorTest < ActiveSupport::TestCase
    test "StepUpRequiredError can be instantiated" do
      error = StepUpRequiredError.new

      assert_match(
        /Translation missing: ja.errors.social_auth.step_up_required|この操作には最近の再認証が必要です/,
        error.message,
      )
      assert_equal :forbidden, error.status_code
    end

    test "StepUpRequiredError includes return_to context" do
      error = StepUpRequiredError.new(return_to: "/some/path")

      assert_equal :forbidden, error.status_code
    end
  end
end
