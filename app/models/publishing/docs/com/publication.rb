# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class Publication < PublishingRecord
        self.table_name = "publishing_docs_com_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
