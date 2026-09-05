# frozen_string_literal: true

# Non-deterministic Active Record Encryption for revision/version title,
# summary, and structured body. PostgreSQL stores ciphertext text; Ruby sees
# String title/summary and a Hash body.
module Publishing
  module EncryptedContent
    extend ActiveSupport::Concern

    included do
      serialize :body, coder: JSON
      encrypts :title, :summary, :body

      validates :title, presence: true
      validates :schema_version, numericality: { greater_than: 0, only_integer: true }
      validate :body_must_be_json_object
    end

    private

    def body_must_be_json_object
      return if body.is_a?(Hash)

      errors.add(:body, "must be a JSON object")
    end
  end
end
