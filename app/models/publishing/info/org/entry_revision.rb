# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_info_org_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
