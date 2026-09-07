# frozen_string_literal: true

module Publishing
  module News
    module App
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_news_app_taxonomy_terms"
        include PublishingTaxonomyTermRecord
      end
    end
  end
end
