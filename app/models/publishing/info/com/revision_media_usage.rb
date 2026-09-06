# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_info_com_revision_media_usages"
        include PublishingRevisionMediaUsageRecord
      end
    end
  end
end
