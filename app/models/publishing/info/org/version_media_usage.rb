# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_info_org_version_media_usages"
        include Publishing::VersionMediaUsageRecord

      end
    end
  end
end
