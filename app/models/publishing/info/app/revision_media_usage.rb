# frozen_string_literal: true

module Publishing
  module Info
    module App
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_info_app_revision_media_usages"
        include Publishing::RevisionMediaUsageRecord

      end
    end
  end
end
