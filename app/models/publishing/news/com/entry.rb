# frozen_string_literal: true

module Publishing
  module News
    module Com
      class Entry < PublishingRecord
        self.table_name = "publishing_news_com_entries"
        include Publishing::EntryRecord

        SURFACE = 'news'
        AUDIENCE = 'com'
        REGION_CODE = "jp"

      end
    end
  end
end
