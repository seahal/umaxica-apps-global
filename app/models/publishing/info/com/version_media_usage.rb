# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_info_com_version_media_usages"
        include PublishingVersionMediaUsageRecord
      end
    end
  end
end
