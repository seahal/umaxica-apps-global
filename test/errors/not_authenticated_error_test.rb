# typed: false
# frozen_string_literal: true

require "test_helper"

class NotAuthenticatedErrorTest < ActiveSupport::TestCase
  test "initializes with default i18n key" do
    error = NotAuthenticatedError.new

    assert_equal "errors.messages.login_required", error.i18n_key
  end

  test "initializes with unauthorized status code" do
    error = NotAuthenticatedError.new

    assert_equal :unauthorized, error.status_code
  end

  test "accepts custom i18n key" do
    I18n.stub(:t, "カスタムエラー") do
      error = NotAuthenticatedError.new("custom.login_required")

      assert_equal "custom.login_required", error.i18n_key
    end
  end

  test "accepts custom status code" do
    error = NotAuthenticatedError.new("errors.messages.login_required", :forbidden)

    assert_equal :forbidden, error.status_code
  end

  test "accepts context keyword arguments" do
    error = NotAuthenticatedError.new(attempted_path: "/dashboard")

    assert_equal "/dashboard", error.context[:attempted_path]
  end

  test "inherits from ApplicationError" do
    assert_kind_of ApplicationError, NotAuthenticatedError.new
  end

  test "can be raised and caught" do
    assert_raises(NotAuthenticatedError) do
      raise NotAuthenticatedError.new
    end
  end
end
