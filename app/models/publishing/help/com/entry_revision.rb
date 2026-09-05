# frozen_string_literal: true

module Publishing
  module Help
    module Com
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_help_com_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
