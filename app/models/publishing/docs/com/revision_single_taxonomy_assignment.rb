# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class RevisionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_docs_com_revision_single_taxonomy_assignments"
        include Publishing::FamilyTaxonomyAssignment


        belongs_to :entry_revision, class_name: "Publishing::Docs::Com::EntryRevision", inverse_of: :single_taxonomy_assignments

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
