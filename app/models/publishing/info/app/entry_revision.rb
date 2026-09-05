# frozen_string_literal: true

module Publishing
  module Info
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_info_app_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
