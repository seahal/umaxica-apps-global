# frozen_string_literal: true

module Publishing
  module News
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_news_app_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
