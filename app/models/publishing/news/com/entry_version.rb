# frozen_string_literal: true

module Publishing
  module News
    module Com
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_news_com_entry_versions"
        include PublishingEntryVersionRecord
      end
    end
  end
end
