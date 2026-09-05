# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_info_com_vocabularies"
        include Publishing::VocabularyRecord

      end
    end
  end
end
