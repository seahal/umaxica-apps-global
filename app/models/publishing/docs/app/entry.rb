# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class Entry < PublishingRecord
        self.table_name = "publishing_docs_app_entries"
        include Publishing::EntryRecord

        SURFACE = 'docs'
        AUDIENCE = 'app'
        REGION_CODE = "jp"

      end
    end
  end
end
