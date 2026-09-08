# frozen_string_literal: true

module Publishing
  module News
    module App
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_news_app_entry_versions"
        include PublishingEntryVersionRecord
      end
    end
  end
end
