# typed: false
# frozen_string_literal: true

module News
  module App
    class ContentEntry < AppRpRecord
      include ReadOnlyContentEntry

      self.table_name = "news_content_entries"
    end
  end
end
