# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_docs_app_entry_revisions"
        include PublishingEntryRevisionRecord
      end
    end
  end
end
