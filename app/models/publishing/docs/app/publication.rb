# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class Publication < PublishingRecord
        self.table_name = "publishing_docs_app_publications"
        include PublishingPublicationRecord

      end
    end
  end
end
