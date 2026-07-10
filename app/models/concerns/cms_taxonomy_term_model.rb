# typed: false
# frozen_string_literal: true

module CmsTaxonomyTermModel
  extend ActiveSupport::Concern
  include PublicId
  include Cms::Archivable

  included do
    before_validation :normalize_cms_taxonomy_name
    validates :locale, :slug, :name, :normalized_name, presence: true
    validates :slug, format: { with: Cms::SlugRules::FORMAT }, uniqueness: { scope: :locale }
    validates :normalized_name, uniqueness: { scope: :locale }
    validate :taxonomy_identity_is_immutable, on: :update
  end

  private

  def normalize_cms_taxonomy_name
    self.normalized_name = Cms::TaxonomyNormalization.normalize(name) if name.present?
  end

  def taxonomy_identity_is_immutable
    %w(locale slug).each { |attribute| errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute) }
  end
end

module Cms
  TaxonomyTermModel = ::CmsTaxonomyTermModel
end
