# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class RevisionMultipleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_info_com_revision_multiple_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment

        belongs_to :entry_revision, class_name: "Publishing::Info::Com::EntryRevision",
                                    inverse_of: :multiple_taxonomy_assignments
        scope :ordered, -> { order(:position) }

        def self.expected_kind = Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT
      end
    end
  end
end
