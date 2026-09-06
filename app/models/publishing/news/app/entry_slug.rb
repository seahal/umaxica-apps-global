# frozen_string_literal: true

module Publishing
  module News
    module App
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_news_app_entry_slugs"
        include PublishingEntrySlugRecord

      end
    end
  end
end
