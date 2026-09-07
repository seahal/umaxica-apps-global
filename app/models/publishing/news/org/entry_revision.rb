# frozen_string_literal: true

module Publishing
  module News
    module Org
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_news_org_entry_revisions"
        include PublishingEntryRevisionRecord
      end
    end
  end
end
