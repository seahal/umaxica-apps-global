# frozen_string_literal: true

module Publishing
  module News
    module Com
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_news_com_entry_slugs"
        include Publishing::EntrySlugRecord

      end
    end
  end
end
