# typed: false
# frozen_string_literal: true

module CmsTaxonomyAssignmentModel
  extend ActiveSupport::Concern
  include PublicId
  include Cms::ImmutableRecord

  included do
    validates :public_id, :locale, :taxonomy_public_id_snapshot, :slug_snapshot, :name_snapshot,
              :path_snapshot, :created_at, presence: true
    validate :path_snapshot_is_an_array
  end

  private

  def path_snapshot_is_an_array
    errors.add(:path_snapshot, "must be an array") unless path_snapshot.is_a?(Array)
  end
end

module Cms
  TaxonomyAssignmentModel = ::CmsTaxonomyAssignmentModel
end
