# frozen_string_literal: true

module Publishing
  module News
    module App
      class Entry < PublishingRecord
        self.table_name = "publishing_news_app_entries"
        include PublishingEntryRecord

        SURFACE = 'news'
        AUDIENCE = 'app'
        REGION_CODE = "jp"

      end
    end
  end
end
