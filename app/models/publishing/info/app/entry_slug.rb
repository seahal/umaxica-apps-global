# frozen_string_literal: true

module Publishing
  module Info
    module App
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_info_app_entry_slugs"
        include Publishing::EntrySlugRecord

      end
    end
  end
end
