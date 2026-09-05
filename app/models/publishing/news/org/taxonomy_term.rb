# frozen_string_literal: true

module Publishing
  module News
    module Org
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_news_org_taxonomy_terms"
        include Publishing::TaxonomyTermRecord

      end
    end
  end
end
