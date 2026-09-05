# frozen_string_literal: true

module Publishing
  module News
    module Org
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_news_org_version_media_usages"
        include Publishing::VersionMediaUsageRecord

      end
    end
  end
end
