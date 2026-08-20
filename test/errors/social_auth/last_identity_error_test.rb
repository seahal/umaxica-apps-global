# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module SocialAuth
  class LastIdentityErrorTest < ActiveSupport::TestCase
    test "initializes with default i18n key" do
      error = LastIdentityError.new

      assert_equal "errors.social_auth.last_identity", error.i18n_key
    end

    test "initializes with unprocessable_content status code" do
      error = LastIdentityError.new

      assert_equal :unprocessable_content, error.status_code
    end

    test "accepts custom i18n key" do
      I18n.stub(:t, "カスタムエラー") do
        error = LastIdentityError.new("custom.last_identity")

        assert_equal "custom.last_identity", error.i18n_key
      end
    end

    test "accepts context keyword arguments" do
      error = LastIdentityError.new(provider: "google", user_id: 42)

      assert_equal "google", error.context[:provider]
      assert_equal 42, error.context[:user_id]
    end

    test "inherits from SocialAuth::BaseError" do
      assert_kind_of SocialAuth::BaseError, LastIdentityError.new
    end

    test "inherits from ApplicationError" do
      assert_kind_of ApplicationError, LastIdentityError.new
    end

    test "can be raised and caught" do
      assert_raises(LastIdentityError) do
        raise LastIdentityError.new
      end
    end

    test "can be raised and caught as SocialAuth::BaseError" do
      assert_raises(SocialAuth::BaseError) do
        raise LastIdentityError.new
      end
    end
  end
end
