# frozen_string_literal: true

module Publishing
  module Info
    module App
      class Publication < PublishingRecord
        self.table_name = "publishing_info_app_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
