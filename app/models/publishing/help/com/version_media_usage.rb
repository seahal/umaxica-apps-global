# frozen_string_literal: true

module Publishing
  module Help
    module Com
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_help_com_version_media_usages"
        include Publishing::VersionMediaUsageRecord

      end
    end
  end
end
