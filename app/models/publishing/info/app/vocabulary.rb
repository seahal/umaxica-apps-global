# frozen_string_literal: true

module Publishing
  module Info
    module App
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_info_app_vocabularies"
        include PublishingVocabularyRecord

      end
    end
  end
end
