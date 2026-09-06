# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_docs_app_vocabularies"
        include PublishingVocabularyRecord

      end
    end
  end
end
