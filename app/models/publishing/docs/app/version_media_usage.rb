# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class VersionMediaUsage < PublishingRecord
        self.table_name = "publishing_docs_app_version_media_usages"
        include PublishingVersionMediaUsageRecord
      end
    end
  end
end
