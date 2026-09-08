# frozen_string_literal: true

module Publishing
  module News
    module Org
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_news_org_vocabularies"
        include PublishingVocabularyRecord
      end
    end
  end
end
