# typed: false
# frozen_string_literal: true

module News
  module Org
    class ContentEntry < OrgRpRecord
      include ReadOnlyContentEntry

      self.table_name = "news_content_entries"
    end
  end
end
