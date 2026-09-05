# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_docs_app_entry_versions"
        include Publishing::EntryVersionRecord

      end
    end
  end
end
