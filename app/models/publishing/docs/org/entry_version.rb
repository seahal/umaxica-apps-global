# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_docs_org_entry_versions"
        include PublishingEntryVersionRecord
      end
    end
  end
end
