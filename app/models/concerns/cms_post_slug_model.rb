# typed: false
# frozen_string_literal: true

module CmsPostSlugModel
  extend ActiveSupport::Concern
  include PublicId

  class_methods do
    def cms_post_slug_model(post_class_name:)
      belongs_to :post, class_name: post_class_name, foreign_key: :post_id, inverse_of: :slugs
    end
  end

  included do
    validates :locale, :slug, :state, presence: true
    validates :slug, format: { with: Cms::SlugRules::FORMAT }, uniqueness: { scope: :locale }
    validates :state, inclusion: { in: Cms::SlugRules::STATES }
    validates :state, uniqueness: { scope: :post_id }, if: -> { %w(reserved canonical).include?(state) }
    validate :slug_timestamps_are_consistent
    validate :slug_identity_is_immutable, on: :update
    before_destroy { throw(:abort) }
    scope :reserved, -> { where(state: "reserved") }
    scope :canonical, -> { where(state: "canonical") }
    scope :redirect, -> { where(state: "redirect") }
  end

  private

  def slug_timestamps_are_consistent
    return if Cms::SlugRules.timestamps_valid?(state:, canonicalized_at:, redirected_at:)

    errors.add(:state, "timestamps are inconsistent")
  end

  def slug_identity_is_immutable
    %w(locale slug post_id).each { |attribute| errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute) }
  end
end

module Cms
  PostSlugModel = ::CmsPostSlugModel
end
