# frozen_string_literal: true

module Publishing
  module News
    module Com
      class Publication < PublishingRecord
        self.table_name = "publishing_news_com_publications"
        include PublishingPublicationRecord

      end
    end
  end
end
