# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_info_com_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
