# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class InvalidUserStatusErrorTest < ActiveSupport::TestCase
  def test_invalid_status_is_exposed
    error = InvalidUserStatusError.new(invalid_status: "BANNED")

    assert_equal "BANNED", error.invalid_status
  end

  def test_message_includes_status
    error = InvalidUserStatusError.new(invalid_status: "SUSPENDED", message: "Bad status")

    assert_equal "Bad status: {invalid_status: \"SUSPENDED\"}", error.message
  end

  def test_message_with_i18n_key
    # We need a valid i18n key that exists in the test environment.
    # In this environment, it seems "errors.messages.invalid" translates to Japanese.
    error = InvalidUserStatusError.new(invalid_status: "BANNED", i18n_key: "errors.messages.invalid")

    # Verify it doesn't use the default message
    assert_not_equal "Invalid user status: BANNED", error.message
    # And it contains some content from the translation
    assert_match(/(invalid|不正な値)/i, error.message)
  end

  def test_default_message_when_no_i18n_key
    error = InvalidUserStatusError.new(invalid_status: "DELETED")

    assert_equal "Invalid user status: DELETED", error.message
  end

  def test_invalid_user_status_error_status_code
    error = InvalidUserStatusError.new(invalid_status: "BANNED")

    assert_equal :unprocessable_entity, error.status_code
  end

  def test_invalid_user_status_error_is_application_error
    error = InvalidUserStatusError.new(invalid_status: "BANNED")

    assert_kind_of ApplicationError, error
  end

  def test_context_includes_invalid_status
    error = InvalidUserStatusError.new(invalid_status: "FROZEN")

    assert_equal "FROZEN", error.context[:invalid_status]
  end

  def test_message_with_custom_context
    error = InvalidUserStatusError.new(invalid_status: "REVOKED", extra_info: "test")

    assert_equal "REVOKED", error.invalid_status
    assert_equal "test", error.context[:extra_info]
  end
end
