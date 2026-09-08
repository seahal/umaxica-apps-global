# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_docs_app_taxonomy_terms"
        include PublishingTaxonomyTermRecord
      end
    end
  end
end
