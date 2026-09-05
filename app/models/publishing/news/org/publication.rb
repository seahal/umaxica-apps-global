# frozen_string_literal: true

module Publishing
  module News
    module Org
      class Publication < PublishingRecord
        self.table_name = "publishing_news_org_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
