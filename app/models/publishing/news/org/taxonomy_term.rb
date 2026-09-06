# frozen_string_literal: true

module Publishing
  module News
    module Org
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_news_org_taxonomy_terms"
        include PublishingTaxonomyTermRecord

      end
    end
  end
end
