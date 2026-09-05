# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_docs_com_vocabularies"
        include Publishing::VocabularyRecord

      end
    end
  end
end
