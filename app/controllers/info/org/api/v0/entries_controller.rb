# typed: false
# frozen_string_literal: true

module Info
  module Org
    module Api
      module V0
        class EntriesController < Info::Org::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "info"
          ENTRY_CLASS = ::Publishing::Info::Org::Entry

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
