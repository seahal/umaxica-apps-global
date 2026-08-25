# frozen_string_literal: true

module Publishing
  # Editable draft assignment for a single_hierarchical vocabulary: at most one
  # term per vocabulary per revision, enforced by
  # UNIQUE(entry_revision_id, vocabulary_id).
  class RevisionSingleTaxonomyAssignment < PublishingRecord
    self.table_name = "publishing_revision_single_taxonomy_assignments"

    include PublishingTaxonomyAssignment

    belongs_to :entry_revision, class_name: "Publishing::EntryRevision", inverse_of: :single_taxonomy_assignments

    def self.expected_kind = TaxonomyKind::SINGLE_HIERARCHICAL
  end
end
