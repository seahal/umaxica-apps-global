# frozen_string_literal: true

module Publishing
  module News
    module Com
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_news_com_entry_revisions"
        include PublishingEntryRevisionRecord
      end
    end
  end
end
