# frozen_string_literal: true

module Publishing
  module Help
    module App
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_help_app_entry_versions"
        include Publishing::EntryVersionRecord

      end
    end
  end
end
