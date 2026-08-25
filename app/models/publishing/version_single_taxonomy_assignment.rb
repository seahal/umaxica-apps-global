# frozen_string_literal: true

module Publishing
  # Immutable snapshot of a single_hierarchical assignment, written once during
  # promotion and frozen by a PostgreSQL trigger thereafter.
  class VersionSingleTaxonomyAssignment < PublishingRecord
    self.table_name = "publishing_version_single_taxonomy_assignments"

    include PublishingTaxonomyAssignment
    include PublishingTaxonomySnapshot

    belongs_to :entry_version, class_name: "Publishing::EntryVersion", inverse_of: :single_taxonomy_assignments

    def self.expected_kind = TaxonomyKind::SINGLE_HIERARCHICAL
  end
end
