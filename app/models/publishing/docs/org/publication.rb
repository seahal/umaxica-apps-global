# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class Publication < PublishingRecord
        self.table_name = "publishing_docs_org_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
