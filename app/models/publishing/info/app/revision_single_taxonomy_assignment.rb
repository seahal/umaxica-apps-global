# frozen_string_literal: true

module Publishing
  module Info
    module App
      class RevisionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_info_app_revision_single_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment


        belongs_to :entry_revision, class_name: "Publishing::Info::App::EntryRevision", inverse_of: :single_taxonomy_assignments

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
