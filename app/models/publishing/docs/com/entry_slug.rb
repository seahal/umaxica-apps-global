# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_docs_com_entry_slugs"
        include PublishingEntrySlugRecord
      end
    end
  end
end
