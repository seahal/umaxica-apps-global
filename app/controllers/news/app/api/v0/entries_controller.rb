# typed: false
# frozen_string_literal: true

module News
  module App
    module Api
      module V0
        class EntriesController < News::App::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "app"
          PUBLISHING_SURFACE = "news"
        end
      end
    end
  end
end
