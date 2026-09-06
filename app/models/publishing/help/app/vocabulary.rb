# frozen_string_literal: true

module Publishing
  module Help
    module App
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_help_app_vocabularies"
        include PublishingVocabularyRecord

      end
    end
  end
end
