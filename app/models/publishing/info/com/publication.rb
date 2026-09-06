# frozen_string_literal: true

module Publishing
  module Info
    module Com
      class Publication < PublishingRecord
        self.table_name = "publishing_info_com_publications"
        include PublishingPublicationRecord
      end
    end
  end
end
