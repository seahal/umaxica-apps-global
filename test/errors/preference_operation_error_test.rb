# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class PreferenceOperationErrorTest < ActiveSupport::TestCase
  test "initializes with default i18n key" do
    error = PreferenceOperationError.new

    assert_equal "errors.messages.preference_operation_failed", error.i18n_key
  end

  test "initializes with default status code" do
    error = PreferenceOperationError.new

    assert_equal :unprocessable_entity, error.status_code
  end

  test "accepts custom i18n key" do
    I18n.stub(:t, "カスタムエラー") do
      error = PreferenceOperationError.new("custom.preference_error")

      assert_equal "custom.preference_error", error.i18n_key
    end
  end

  test "accepts custom status code" do
    I18n.stub(:t, "カスタムエラー") do
      error = PreferenceOperationError.new("custom.preference_error", :bad_request)

      assert_equal :bad_request, error.status_code
    end
  end

  test "accepts context keyword arguments" do
    error = PreferenceOperationError.new(operation: "update")

    assert_equal "update", error.context[:operation]
  end

  test "inherits from ApplicationError" do
    assert_kind_of ApplicationError, PreferenceOperationError.new
  end

  test "can be raised and caught" do
    assert_raises(PreferenceOperationError) do
      raise PreferenceOperationError.new
    end
  end
end
