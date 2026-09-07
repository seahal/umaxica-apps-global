# frozen_string_literal: true

module Publishing
  module News
    module App
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_news_app_vocabularies"
        include PublishingVocabularyRecord
      end
    end
  end
end
