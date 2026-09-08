# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_info_com_entry_slugs"
        include PublishingEntrySlugRecord
      end
    end
  end
end
