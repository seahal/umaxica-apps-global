# frozen_string_literal: true

module Publishing
  module Help
    module Com
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_help_com_vocabularies"
        include Publishing::VocabularyRecord

      end
    end
  end
end
