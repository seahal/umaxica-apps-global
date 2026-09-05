# frozen_string_literal: true

module Publishing
  module Help
    module App
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_help_app_entry_slugs"
        include Publishing::EntrySlugRecord

      end
    end
  end
end
