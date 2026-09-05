# frozen_string_literal: true

module Publishing
  module News
    module Com
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_news_com_vocabularies"
        include Publishing::VocabularyRecord

      end
    end
  end
end
