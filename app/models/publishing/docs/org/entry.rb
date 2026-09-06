# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class Entry < PublishingRecord
        self.table_name = "publishing_docs_org_entries"
        include PublishingEntryRecord

        SURFACE = "docs"
        AUDIENCE = "org"
        REGION_CODE = "jp"
      end
    end
  end
end
