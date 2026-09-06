# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_help_org_entry_revisions"
        include PublishingEntryRevisionRecord

      end
    end
  end
end
