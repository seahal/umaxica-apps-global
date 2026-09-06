# frozen_string_literal: true

module Publishing
  module News
    module Com
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_news_com_version_media_usages"
        include PublishingVersionMediaUsageRecord
      end
    end
  end
end
