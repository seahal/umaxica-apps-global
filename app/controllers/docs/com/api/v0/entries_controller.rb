# typed: false
# frozen_string_literal: true

module Docs
  module Com
    module Api
      module V0
        class EntriesController < Docs::Com::BareController
          include ::PublishingContentRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "com"
          PUBLISHING_SURFACE = "docs"

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
