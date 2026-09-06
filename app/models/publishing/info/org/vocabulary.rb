# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_info_org_vocabularies"
        include PublishingVocabularyRecord

      end
    end
  end
end
