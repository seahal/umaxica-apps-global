# frozen_string_literal: true

module Publishing
  module Help
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_help_app_entry_revisions"
        include PublishingEntryRevisionRecord
      end
    end
  end
end
