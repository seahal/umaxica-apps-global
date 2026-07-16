# typed: false
# frozen_string_literal: true

module Help
  module App
    module Api
      module V0
        class EntriesController < Help::App::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "app"
          PUBLISHING_SURFACE = "help"
        end
      end
    end
  end
end
