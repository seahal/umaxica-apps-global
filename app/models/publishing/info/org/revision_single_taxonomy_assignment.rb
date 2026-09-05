# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class RevisionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_info_org_revision_single_taxonomy_assignments"
        include Publishing::FamilyTaxonomyAssignment


        belongs_to :entry_revision, class_name: "Publishing::Info::Org::EntryRevision", inverse_of: :single_taxonomy_assignments

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
