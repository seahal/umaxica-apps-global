# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_docs_com_taxonomy_terms"
        include Publishing::TaxonomyTermRecord

      end
    end
  end
end
