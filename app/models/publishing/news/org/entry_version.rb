# frozen_string_literal: true

module Publishing
  module News
    module Org
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_news_org_entry_versions"
        include PublishingEntryVersionRecord

      end
    end
  end
end
