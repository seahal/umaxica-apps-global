# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_help_org_entry_slugs"
        include Publishing::EntrySlugRecord

      end
    end
  end
end
