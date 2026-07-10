# typed: false
# frozen_string_literal: true

module Cms
  module MediaFileModel
    extend ActiveSupport::Concern
    include PublicId
    include Cms::Archivable

    class_methods do
      def cms_media_file_model(media_usage_class_name:)
        has_many :media_usages, class_name: media_usage_class_name, foreign_key: :media_file_id,
                                inverse_of: :media_file, dependent: :restrict_with_exception
      end
    end

    included do
      validates :storage_key, :content_type, :digest_algorithm, :digest, presence: true
      validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :digest_algorithm, inclusion: { in: %w(sha256) }
      validates :digest, format: { with: /\A[0-9a-f]{64}\z/ }
      validate :media_dimensions_and_metadata
      validate :binary_identity_is_immutable, on: :update
    end

    private

    def media_dimensions_and_metadata
      errors.add(:metadata, "must be an object") unless metadata.is_a?(Hash)
      dimensions = [width, height]
      return if dimensions.all?(&:nil?) || dimensions.all? { |value| value.is_a?(Integer) && value.positive? }

      errors.add(:base, "width and height must both be positive or both be absent")
    end

    def binary_identity_is_immutable
      %w(storage_key content_type byte_size digest_algorithm digest).each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end
  end
end
