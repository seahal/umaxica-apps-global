# typed: false
# frozen_string_literal: true

class InvalidUserStatusError < ApplicationError
  attr_reader :invalid_status

  def initialize(invalid_status:, i18n_key: nil, **context)
    @invalid_status = invalid_status
    super(i18n_key, :unprocessable_content, invalid_status: invalid_status, **context)
  end

  def message
    provided_message = context[:message]
    if provided_message
      "#{provided_message}: {invalid_status: #{invalid_status.inspect}}"
    elsif i18n_key
      super
    else
      "Invalid user status: #{invalid_status}"
    end
  end
end
