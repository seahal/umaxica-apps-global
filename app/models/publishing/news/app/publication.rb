# frozen_string_literal: true

module Publishing
  module News
    module App
      class Publication < PublishingRecord
        self.table_name = "publishing_news_app_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
