# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_docs_com_entry_revisions"
        include Publishing::EntryRevisionRecord

      end
    end
  end
end
