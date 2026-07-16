# typed: false
# frozen_string_literal: true

module Docs
  module Org
    module Api
      module V0
        class EntriesController < Docs::Org::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "docs"
        end
      end
    end
  end
end
