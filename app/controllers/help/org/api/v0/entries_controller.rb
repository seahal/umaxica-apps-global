# typed: false
# frozen_string_literal: true

module Help
  module Org
    module Api
      module V0
        class EntriesController < Help::Org::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "help"
          ENTRY_CLASS = ::Publishing::Help::Org::Entry

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
