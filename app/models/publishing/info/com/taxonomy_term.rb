# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_info_com_taxonomy_terms"
        include PublishingTaxonomyTermRecord
      end
    end
  end
end
