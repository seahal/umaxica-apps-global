# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class RevisionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_docs_org_revision_single_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment

        belongs_to :entry_revision, class_name: "Publishing::Docs::Org::EntryRevision",
                                    inverse_of: :single_taxonomy_assignments

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
