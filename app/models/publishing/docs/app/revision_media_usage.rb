# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_docs_app_revision_media_usages"
        include Publishing::RevisionMediaUsageRecord

      end
    end
  end
end
