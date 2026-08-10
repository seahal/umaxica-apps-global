# typed: false
# frozen_string_literal: true

module Info
  module App
    module Api
      module V0
        class EntriesController < Info::App::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "app"
          PUBLISHING_SURFACE = "info"

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
