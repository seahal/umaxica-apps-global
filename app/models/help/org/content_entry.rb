# typed: false
# frozen_string_literal: true

module Help
  module Org
    class ContentEntry < OrgRpRecord
      include ReadOnlyContentEntry

      self.table_name = "help_content_entries"
    end
  end
end
