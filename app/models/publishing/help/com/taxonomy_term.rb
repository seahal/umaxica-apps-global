# frozen_string_literal: true

module Publishing
  module Help
    module Com
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_help_com_taxonomy_terms"
        include PublishingTaxonomyTermRecord
      end
    end
  end
end
