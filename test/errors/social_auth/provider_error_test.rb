# typed: false
# frozen_string_literal: true

require "test_helper"

module SocialAuth
  class ProviderErrorTest < ActiveSupport::TestCase
    test "SocialAuth::ProviderError initializes with default i18n key" do
      error = SocialAuth::ProviderError.new

      assert_equal "errors.social_auth.provider_error", error.i18n_key
    end

    test "SocialAuth::ProviderError initializes with bad_request status code" do
      error = SocialAuth::ProviderError.new

      assert_equal :bad_request, error.status_code
    end

    test "SocialAuth::ProviderError can be instantiated with custom message" do
      error = SocialAuth::ProviderError.new("custom.error.key")

      assert_equal "custom.error.key", error.i18n_key
    end

    test "SocialAuth::ProviderError includes context" do
      error = SocialAuth::ProviderError.new("errors.social_auth.provider_error", provider: "google")

      assert_equal :bad_request, error.status_code
      assert_equal "google", error.context[:provider]
    end

    test "SocialAuth::ProviderError inherits from SocialAuth::BaseError" do
      assert_kind_of SocialAuth::BaseError, SocialAuth::ProviderError.new
    end

    test "SocialAuth::ProviderError inherits from ApplicationError" do
      assert_kind_of ApplicationError, SocialAuth::ProviderError.new
    end

    test "SocialAuth::ProviderError can be raised and caught" do
      assert_raises(SocialAuth::ProviderError) do
        raise SocialAuth::ProviderError.new
      end
    end

    test "SocialAuth::ProviderError can be raised and caught as BaseError" do
      assert_raises(SocialAuth::BaseError) do
        raise SocialAuth::ProviderError.new
      end
    end
  end
end
