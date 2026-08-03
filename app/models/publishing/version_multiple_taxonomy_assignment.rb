# frozen_string_literal: true

module Publishing
  # Immutable snapshot of a multiple_ordered_flat assignment. position mirrors
  # the draft order at promotion time; position_snapshot records it as frozen
  # history alongside the other snapshot columns.
  class VersionMultipleTaxonomyAssignment < PublishingRecord
    self.table_name = "publishing_version_multiple_taxonomy_assignments"

    include PublishingTaxonomyAssignment
    include PublishingTaxonomySnapshot

    belongs_to :entry_version, class_name: "Publishing::EntryVersion", inverse_of: :multiple_taxonomy_assignments

    scope :ordered, -> { order(:position) }

    def self.expected_kind = TaxonomyKind::MULTIPLE_ORDERED_FLAT

    def apply_snapshot(vocabulary:, term:)
      super
      self.position_snapshot = position
      self
    end
  end
end
