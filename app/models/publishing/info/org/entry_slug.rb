# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_info_org_entry_slugs"
        include Publishing::EntrySlugRecord

      end
    end
  end
end
