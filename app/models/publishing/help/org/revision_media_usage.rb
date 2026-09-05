# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_help_org_revision_media_usages"
        include Publishing::RevisionMediaUsageRecord

      end
    end
  end
end
