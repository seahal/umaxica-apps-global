# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_docs_org_version_media_usages"
        include Publishing::VersionMediaUsageRecord

      end
    end
  end
end
