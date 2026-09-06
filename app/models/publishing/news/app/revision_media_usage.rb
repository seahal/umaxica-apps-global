# frozen_string_literal: true

module Publishing
  module News
    module App
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_news_app_revision_media_usages"
        include PublishingRevisionMediaUsageRecord

      end
    end
  end
end
