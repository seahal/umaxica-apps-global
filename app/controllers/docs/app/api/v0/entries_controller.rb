# typed: false
# frozen_string_literal: true

module Docs
  module App
    module Api
      module V0
        class EntriesController < Docs::App::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "app"
          PUBLISHING_SURFACE = "docs"
        end
      end
    end
  end
end
