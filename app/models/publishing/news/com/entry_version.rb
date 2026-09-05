# frozen_string_literal: true

module Publishing
  module News
    module Com
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_news_com_entry_versions"
        include Publishing::EntryVersionRecord

      end
    end
  end
end
