# typed: false
# frozen_string_literal: true

module Docs
  module Org
    class ContentEntry < OrgRpRecord
      include ReadOnlyContentEntry

      self.table_name = "docs_content_entries"
    end
  end
end
