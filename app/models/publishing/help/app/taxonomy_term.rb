# frozen_string_literal: true

module Publishing
  module Help
    module App
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_help_app_taxonomy_terms"
        include Publishing::TaxonomyTermRecord

      end
    end
  end
end
