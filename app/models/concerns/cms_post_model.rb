# typed: false
# frozen_string_literal: true

module CmsPostModel
  extend ActiveSupport::Concern
  include PublicId
  include Cms::Archivable

  class_methods do
    def cms_post_model(revision_class_name:, slug_class_name:, version_class_name:, publication_class_name:, media_usage_class_name:)
      belongs_to :current_revision, class_name: revision_class_name,
                                    inverse_of: :current_for_post, optional: true
      has_many :slugs, class_name: slug_class_name, foreign_key: :post_id, inverse_of: :post,
                       dependent: :restrict_with_exception
      has_many :revisions, class_name: revision_class_name, foreign_key: :post_id, inverse_of: :post,
                           dependent: :restrict_with_exception
      has_many :versions, class_name: version_class_name, foreign_key: :post_id, inverse_of: :post,
                          dependent: :restrict_with_exception
      has_many :publications, class_name: publication_class_name, foreign_key: :post_id, inverse_of: :post,
                              dependent: :restrict_with_exception
      has_many :media_usages, class_name: media_usage_class_name, foreign_key: :post_id, inverse_of: :post,
                              dependent: :restrict_with_exception
    end
  end

  included do
    validates :locale, presence: true
    validates :lock_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validate :current_revision_belongs_to_post
    validate :post_identity_is_immutable, on: :update
    before_destroy { throw(:abort) }
  end

  private

  def current_revision_belongs_to_post
    errors.add(:current_revision, "must belong to the same post") if current_revision.present? && current_revision.post != self
  end

  def post_identity_is_immutable
    errors.add(:locale, "cannot be changed") if will_save_change_to_locale?
  end
end

module Cms
  PostModel = ::CmsPostModel
end
