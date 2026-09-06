# frozen_string_literal: true

module Publishing
  module News
    module Org
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_news_org_revision_media_usages"
        include PublishingRevisionMediaUsageRecord
      end
    end
  end
end
