# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class VersionMultipleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_docs_com_version_multiple_taxonomy_assignments"
        include Publishing::FamilyTaxonomyAssignment
        include PublishingTaxonomySnapshot


        belongs_to :entry_version, class_name: "Publishing::Docs::Com::EntryVersion", inverse_of: :multiple_taxonomy_assignments
        scope :ordered, -> { order(:position) }

        def self.expected_kind = Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT

        def apply_snapshot(vocabulary:, term:)
          super
          self.position_snapshot = position
          self
        end
      end
    end
  end
end
