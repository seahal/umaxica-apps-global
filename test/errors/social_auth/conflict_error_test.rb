# typed: false
# frozen_string_literal: true

require "test_helper"

module SocialAuth
  class ConflictErrorTest < ActiveSupport::TestCase
    test "ConflictError can be instantiated with default message" do
      error = ConflictError.new

      assert_equal "errors.social_auth.conflict", error.i18n_key
    end

    test "ConflictError initializes with conflict status code" do
      error = ConflictError.new

      assert_equal :conflict, error.status_code
    end

    test "ConflictError can be instantiated with custom i18n key" do
      error = ConflictError.new("errors.social_auth.conflict")

      assert_equal "errors.social_auth.conflict", error.i18n_key
      assert_equal :conflict, error.status_code
    end

    test "ConflictError includes context" do
      error = ConflictError.new("errors.social_auth.conflict", user_id: 123)

      assert_equal :conflict, error.status_code
      assert_equal 123, error.context[:user_id]
    end

    test "ConflictError inherits from SocialAuth::BaseError" do
      assert_kind_of SocialAuth::BaseError, ConflictError.new
    end

    test "ConflictError inherits from ApplicationError" do
      assert_kind_of ApplicationError, ConflictError.new
    end

    test "ConflictError can be raised and caught" do
      assert_raises(ConflictError) do
        raise ConflictError.new
      end
    end

    test "ConflictError can be raised and caught as BaseError" do
      assert_raises(SocialAuth::BaseError) do
        raise ConflictError.new
      end
    end
  end
end
