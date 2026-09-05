# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class RevisionMediaUsage < PublishingRecord
        self.table_name = "publishing_docs_com_revision_media_usages"
        include Publishing::RevisionMediaUsageRecord

      end
    end
  end
end
