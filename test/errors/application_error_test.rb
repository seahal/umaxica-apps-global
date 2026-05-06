# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationErrorTest < ActiveSupport::TestCase
  def test_application_error_inherits_from_standard_error
    error = ApplicationError.new

    assert_kind_of StandardError, error
  end

  def test_application_error_initializes_with_defaults
    error = ApplicationError.new

    assert_nil error.i18n_key
    assert_equal :internal_server_error, error.status_code
    assert_empty(error.context)
  end

  def test_application_error_with_i18n_key
    error = ApplicationError.new("test.error.key", :bad_request)

    assert_equal "test.error.key", error.i18n_key
    assert_equal :bad_request, error.status_code
  end

  def test_application_error_with_context
    context = { user_id: 123, action: "create" }
    error = ApplicationError.new("test.error.key", :bad_request, **context)

    assert_equal context, error.context
  end

  def test_application_error_translates_i18n_key_to_message
    error = ApplicationError.new("test.error.key", :bad_request)

    assert_equal "テストエラー", error.message
  end

  def test_application_error_can_be_raised_and_caught
    assert_raises(ApplicationError) do
      raise ApplicationError.new("test.error.key")
    end
  end

  def test_application_error_attributes_are_readable
    error = ApplicationError.new("test.error.key", :forbidden)

    assert_equal "test.error.key", error.i18n_key
    assert_equal :forbidden, error.status_code
  end

  def test_application_error_without_i18n_key_has_message_with_class_name
    error = ApplicationError.new

    assert_operator error.message.length, :>, 0
  end

  def test_application_error_with_multiple_context_keys
    context = { user_id: 1, resource: "document", action: "delete" }
    error = ApplicationError.new("test.error.key", :forbidden, **context)

    assert_equal 3, error.context.size
    assert_equal 1, error.context[:user_id]
  end

  def test_application_error_with_unicode_message
    error = ApplicationError.new("直接日本語メッセージ", :bad_request)

    assert_equal "直接日本語メッセージ", error.message
  end

  def test_application_error_with_unicode_key_that_is_not_translated
    error = ApplicationError.new("nonexistent.error.キー", :bad_request)

    assert_match(/nonexistent|Translation missing|キー/, error.message)
  end

  def test_application_error_status_code_default
    error = ApplicationError.new("test.error.key")

    assert_equal :internal_server_error, error.status_code
  end

  def test_application_error_context_is_empty_when_not_provided
    error = ApplicationError.new("test.error.key", :bad_request)

    assert_empty error.context
  end
end
