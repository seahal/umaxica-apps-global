# typed: false
# frozen_string_literal: true

module Docs
  module Org
    module Api
      module V0
        class EntriesController < Docs::Org::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "docs"
          ENTRY_CLASS = ::Publishing::Docs::Org::Entry

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
