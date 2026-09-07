# frozen_string_literal: true

module Publishing
  module News
    module Com
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_news_com_taxonomy_terms"
        include PublishingTaxonomyTermRecord
      end
    end
  end
end
