# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_help_org_version_media_usages"
        include PublishingVersionMediaUsageRecord

      end
    end
  end
end
