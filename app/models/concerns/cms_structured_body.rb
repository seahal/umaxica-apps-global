# typed: false
# frozen_string_literal: true

require "digest"
require "json"

module CmsStructuredBody
  ALLOWED_BLOCK_TYPES = %w(paragraph heading image attachment callout code table quote related_link).freeze

  module_function

  def canonical_json(value) = JSON.generate(canonical_value(value))

  def digest_for(body) = Digest::SHA256.hexdigest(canonical_json(body))

  def canonical_value(value)
    case value
    when Hash then value.keys.sort.index_with { |key| canonical_value(value.fetch(key)) }
    when Array then value.map { |item| canonical_value(item) }
    else value
    end
  end

  module Validation
    extend ActiveSupport::Concern

    included do
      before_validation :assign_cms_content_digest, on: :create
      validate :validate_cms_structured_body
    end

    private

    def assign_cms_content_digest
      self.content_digest = Cms::StructuredBody.digest_for(body) if content_digest.blank? && body.is_a?(Hash)
    end

    def validate_cms_structured_body
      unless body.is_a?(Hash)
        errors.add(:body, "must be an object")
        return
      end
      errors.add(:schema_version, "must be a positive integer") unless schema_version.is_a?(Integer) && schema_version.positive?
      errors.add(:body, "schema_version must match schema_version") unless body["schema_version"] == schema_version
      blocks = body["blocks"]
      unless blocks.is_a?(Array)
        errors.add(:body, "blocks must be an array")
        return
      end
      errors.add(:body, "contains a non-object block") unless blocks.all?(Hash)
      errors.add(:body, "contains a block without type") unless blocks.all? { |block| block.is_a?(Hash) && block["type"].present? }
      unless blocks.all? { |block| block.is_a?(Hash) && ALLOWED_BLOCK_TYPES.include?(block["type"]) }
        errors.add(:body, "contains an unsupported block type")
      end
      expected = Cms::StructuredBody.digest_for(body)
      errors.add(:content_digest, "must match body") if content_digest.present? && content_digest != expected
    end
  end

  extend ActiveSupport::Concern
  include Validation
end

module Cms
  StructuredBody = ::CmsStructuredBody
end
