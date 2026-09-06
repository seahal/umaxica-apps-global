# frozen_string_literal: true

module Publishing
  module News
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_news_app_entry_revisions"
        include PublishingEntryRevisionRecord

      end
    end
  end
end
