# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_help_org_vocabularies"
        include PublishingVocabularyRecord
      end
    end
  end
end
