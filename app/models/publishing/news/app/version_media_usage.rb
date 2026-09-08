# frozen_string_literal: true

module Publishing
  module News
    module App
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_news_app_version_media_usages"
        include PublishingVersionMediaUsageRecord
      end
    end
  end
end
