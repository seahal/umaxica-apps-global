# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

module SocialAuth
  class StepUpRequiredErrorTest < ActiveSupport::TestCase
    test "StepUpRequiredError initializes with default i18n key" do
      error = StepUpRequiredError.new

      assert_equal "errors.social_auth.step_up_required", error.i18n_key
    end

    test "StepUpRequiredError initializes with forbidden status code" do
      error = StepUpRequiredError.new

      assert_equal :forbidden, error.status_code
    end

    test "StepUpRequiredError can be instantiated" do
      error = StepUpRequiredError.new

      assert_match(
        Regexp.union(
          "Translation missing: ja.errors.social_auth.step_up_required",
          "この操作には最近の再認証が必要です",
          /This action requires recent step-up authentication\. Please authenticate again\./,
        ),
        error.message,
      )
    end

    test "StepUpRequiredError includes context keyword arguments" do
      error = StepUpRequiredError.new(return_to: "/some/path")

      assert_equal "/some/path", error.context[:return_to]
      assert_equal :forbidden, error.status_code
    end

    test "StepUpRequiredError inherits from SocialAuth::BaseError" do
      assert_kind_of SocialAuth::BaseError, StepUpRequiredError.new
    end

    test "StepUpRequiredError inherits from ApplicationError" do
      assert_kind_of ApplicationError, StepUpRequiredError.new
    end

    test "StepUpRequiredError can be raised and caught" do
      assert_raises(StepUpRequiredError) do
        raise StepUpRequiredError.new
      end
    end

    test "StepUpRequiredError can be raised and caught as BaseError" do
      assert_raises(SocialAuth::BaseError) do
        raise StepUpRequiredError.new
      end
    end
  end
end
