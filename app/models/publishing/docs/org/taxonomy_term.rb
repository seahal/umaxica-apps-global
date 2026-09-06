# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_docs_org_taxonomy_terms"
        include PublishingTaxonomyTermRecord

      end
    end
  end
end
