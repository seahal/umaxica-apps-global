# typed: false
# frozen_string_literal: true

module Publishing
  # Input for a staff CMS revision: title, summary, and JSON body text.
  class ReviseEntryForm < ApplicationForm
    attribute :title, :string
    attribute :summary, :string
    attribute :body_text, :string
    attribute :lock_version, :integer

    attr_reader :parsed_body

    validate :title_must_be_present
    validate :body_must_be_json_object

    def message_hash
      errors.details.to_h { |attribute, list|
        [attribute, message_for(attribute, list.first.fetch(:error))]
      }
    end

    private

    def title_must_be_present
      errors.add(:title, :blank) if title.blank?
    end

    def body_must_be_json_object
      if body_text.blank?
        errors.add(:body, :not_object)
        return
      end

      parsed = JSON.parse(body_text)
      unless parsed.is_a?(Hash)
        errors.add(:body, :not_object)
        return
      end

      @parsed_body = parsed
    rescue JSON::ParserError
      errors.add(:body, :malformed)
    end

    def message_for(attribute, error)
      if attribute == :title && error == :blank
        "can't be blank"
      elsif attribute == :body && error == :not_object
        "must be a JSON object"
      elsif attribute == :body && error == :malformed
        "must be valid JSON"
      else
        error.to_s
      end
    end
  end
end
