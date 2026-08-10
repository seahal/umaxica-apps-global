# typed: false
# frozen_string_literal: true

module Help
  module App
    module Api
      module V0
        class EntriesController < Help::App::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "app"
          PUBLISHING_SURFACE = "help"

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
