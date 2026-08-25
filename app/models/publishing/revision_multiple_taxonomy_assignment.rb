# frozen_string_literal: true

module Publishing
  # Editable draft assignment for a multiple_ordered_flat vocabulary: any number
  # of terms per vocabulary, in an author-controlled order. Duplicate terms and
  # duplicate positions are both rejected by unique indexes.
  class RevisionMultipleTaxonomyAssignment < PublishingRecord
    self.table_name = "publishing_revision_multiple_taxonomy_assignments"

    include PublishingTaxonomyAssignment

    belongs_to :entry_revision, class_name: "Publishing::EntryRevision", inverse_of: :multiple_taxonomy_assignments

    scope :ordered, -> { order(:position) }

    def self.expected_kind = TaxonomyKind::MULTIPLE_ORDERED_FLAT
  end
end
