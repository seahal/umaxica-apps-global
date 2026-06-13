# typed: false
# frozen_string_literal: true

module News
  module Com
    class ContentEntry < ComRpRecord
      include ReadOnlyContentEntry

      self.table_name = "news_content_entries"
    end
  end
end
