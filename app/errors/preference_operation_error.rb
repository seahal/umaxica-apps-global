# typed: false
# frozen_string_literal: true

class PreferenceOperationError < ApplicationError
  def initialize(i18n_key = "errors.messages.preference_operation_failed", status_code = :unprocessable_content,
                 **context)
    super
  end
end
