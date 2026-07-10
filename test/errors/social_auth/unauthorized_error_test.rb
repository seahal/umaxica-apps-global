# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module SocialAuth
  class UnauthorizedErrorTest < ActiveSupport::TestCase
    test "initializes with default i18n key" do
      error = UnauthorizedError.new

      assert_equal "errors.social_auth.unauthorized", error.i18n_key
    end

    test "initializes with unauthorized status code" do
      error = UnauthorizedError.new

      assert_equal :unauthorized, error.status_code
    end

    test "accepts custom i18n key" do
      I18n.stub(:t, "カスタムエラー") do
        error = UnauthorizedError.new("custom.social_auth.unauthorized")

        assert_equal "custom.social_auth.unauthorized", error.i18n_key
      end
    end

    test "accepts context keyword arguments" do
      error = UnauthorizedError.new(reason: "state_mismatch")

      assert_equal "state_mismatch", error.context[:reason]
    end

    test "inherits from SocialAuth::BaseError" do
      assert_kind_of SocialAuth::BaseError, UnauthorizedError.new
    end

    test "inherits from ApplicationError" do
      assert_kind_of ApplicationError, UnauthorizedError.new
    end

    test "can be raised and caught" do
      assert_raises(UnauthorizedError) do
        raise UnauthorizedError.new
      end
    end

    test "can be raised and caught as SocialAuth::BaseError" do
      assert_raises(SocialAuth::BaseError) do
        raise UnauthorizedError.new
      end
    end
  end
end
