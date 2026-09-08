# typed: false
# frozen_string_literal: true

module Publishing
  # The content fields every CMS write shares: a title, an optional summary,
  # and a structured body typed into the form as JSON text.
  #
  # The body is validated here rather than in the model because the form is
  # where the text is still text. `Publishing::EncryptedContent` validates the
  # parsed Hash; by then a malformed document has already been rejected here
  # with a message that names what was wrong with it.
  class EntryContentForm < ApplicationForm
    attribute :title, :string
    attribute :summary, :string
    attribute :body_text, :string

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

    # Subclasses extend the map with their own fields. An error with no entry
    # is rendered under its own name rather than dropped, so a validation
    # added without a message is visible instead of silent.
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
