# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_docs_org_vocabularies"
        include Publishing::VocabularyRecord

      end
    end
  end
end
