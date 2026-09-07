# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_docs_com_vocabularies"
        include PublishingVocabularyRecord
      end
    end
  end
end
