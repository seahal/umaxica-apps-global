# typed: false
# frozen_string_literal: true

module Docs
  module App
    class ContentEntry < AppRpRecord
      include ReadOnlyContentEntry

      self.table_name = "docs_content_entries"
    end
  end
end
