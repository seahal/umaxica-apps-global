# typed: false
# frozen_string_literal: true

require "test_helper"

module SocialAuth
  class ProviderErrorTest < ActiveSupport::TestCase
    test "ProviderError initializes with default i18n key" do
      error = ProviderError.new

      assert_equal "errors.social_auth.provider_error", error.i18n_key
    end

    test "ProviderError initializes with bad_request status code" do
      error = ProviderError.new

      assert_equal :bad_request, error.status_code
    end

    test "ProviderError can be instantiated with custom message" do
      error = ProviderError.new("custom.error.key")

      assert_equal "custom.error.key", error.i18n_key
    end

    test "ProviderError includes context" do
      error = ProviderError.new("errors.social_auth.provider_error", provider: "google")

      assert_equal :bad_request, error.status_code
      assert_equal "google", error.context[:provider]
    end

    test "ProviderError inherits from SocialAuth::BaseError" do
      assert_kind_of SocialAuth::BaseError, ProviderError.new
    end

    test "ProviderError inherits from ApplicationError" do
      assert_kind_of ApplicationError, ProviderError.new
    end

    test "ProviderError can be raised and caught" do
      assert_raises(ProviderError) do
        raise ProviderError.new
      end
    end

    test "ProviderError can be raised and caught as BaseError" do
      assert_raises(SocialAuth::BaseError) do
        raise ProviderError.new
      end
    end
  end
end
