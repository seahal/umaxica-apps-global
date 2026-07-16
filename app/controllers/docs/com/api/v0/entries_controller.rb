# typed: false
# frozen_string_literal: true

module Docs
  module Com
    module Api
      module V0
        class EntriesController < Docs::Com::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "com"
          PUBLISHING_SURFACE = "docs"
        end
      end
    end
  end
end
