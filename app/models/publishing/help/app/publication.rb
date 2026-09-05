# frozen_string_literal: true

module Publishing
  module Help
    module App
      class Publication < PublishingRecord
        self.table_name = "publishing_help_app_publications"
        include Publishing::PublicationRecord

      end
    end
  end
end
