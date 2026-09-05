# frozen_string_literal: true

module Publishing
  module Help
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_help_app_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
