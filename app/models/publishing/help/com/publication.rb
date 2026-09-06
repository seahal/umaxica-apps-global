# frozen_string_literal: true

module Publishing
  module Help
    module Com
      class Publication < PublishingRecord
        self.table_name = "publishing_help_com_publications"
        include PublishingPublicationRecord
      end
    end
  end
end
