# typed: false
# frozen_string_literal: true

module Help
  module Com
    class ContentEntry < ComRpRecord
      include ReadOnlyContentEntry

      self.table_name = "help_content_entries"
    end
  end
end
