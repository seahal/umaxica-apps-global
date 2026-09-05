# frozen_string_literal: true

module Publishing
  module Help
    module App
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_help_app_revision_media_usages"
        include Publishing::RevisionMediaUsageRecord

      end
    end
  end
end
