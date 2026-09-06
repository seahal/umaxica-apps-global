# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class VersionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_docs_org_version_single_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment
        include PublishingTaxonomySnapshot

        belongs_to :entry_version, class_name: "Publishing::Docs::Org::EntryVersion",
                                   inverse_of: :single_taxonomy_assignments

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
