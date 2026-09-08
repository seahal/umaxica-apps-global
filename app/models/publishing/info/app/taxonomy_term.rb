# frozen_string_literal: true

module Publishing
  module Info
    module App
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_info_app_taxonomy_terms"
        include PublishingTaxonomyTermRecord
      end
    end
  end
end
