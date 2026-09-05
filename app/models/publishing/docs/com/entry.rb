# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class Entry < PublishingRecord
        self.table_name = "publishing_docs_com_entries"
        include Publishing::EntryRecord

        SURFACE = 'docs'
        AUDIENCE = 'com'
        REGION_CODE = "jp"

      end
    end
  end
end
