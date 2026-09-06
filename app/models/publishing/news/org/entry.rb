# frozen_string_literal: true

module Publishing
  module News
    module Org
      class Entry < PublishingRecord
        self.table_name = "publishing_news_org_entries"
        include PublishingEntryRecord

        SURFACE = "news"
        AUDIENCE = "org"
        REGION_CODE = "jp"
      end
    end
  end
end
