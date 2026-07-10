# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AlreadyAuthenticatedErrorTest < ActiveSupport::TestCase
  test "initializes with default i18n key" do
    error = AlreadyAuthenticatedError.new

    assert_equal "errors.messages.already_authenticated", error.i18n_key
  end

  test "initializes with forbidden status code" do
    error = AlreadyAuthenticatedError.new

    assert_equal :forbidden, error.status_code
  end

  test "accepts custom i18n key" do
    I18n.stub(:t, "カスタムエラー") do
      error = AlreadyAuthenticatedError.new("custom.already_authenticated")

      assert_equal "custom.already_authenticated", error.i18n_key
    end
  end

  test "accepts custom status code" do
    error = AlreadyAuthenticatedError.new("errors.messages.already_authenticated", :unauthorized)

    assert_equal :unauthorized, error.status_code
  end

  test "accepts context keyword arguments" do
    error = AlreadyAuthenticatedError.new(session_id: "abc123")

    assert_equal "abc123", error.context[:session_id]
  end

  test "inherits from ApplicationError" do
    assert_kind_of ApplicationError, AlreadyAuthenticatedError.new
  end

  test "can be raised and caught" do
    assert_raises(AlreadyAuthenticatedError) do
      raise AlreadyAuthenticatedError.new
    end
  end
end
