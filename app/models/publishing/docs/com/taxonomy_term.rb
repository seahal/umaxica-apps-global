# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_docs_com_taxonomy_terms"
        include PublishingTaxonomyTermRecord

      end
    end
  end
end
