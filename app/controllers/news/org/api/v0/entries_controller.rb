# typed: false
# frozen_string_literal: true

module News
  module Org
    module Api
      module V0
        class EntriesController < News::Org::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "news"
          ENTRY_CLASS = ::Publishing::News::Org::Entry

          def index
            render_publishing_entries_index
          end

          def show
            render_publishing_entry_show
          end
        end
      end
    end
  end
end
