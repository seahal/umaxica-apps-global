# typed: false
# frozen_string_literal: true

module Help
  module Org
    module Api
      module V0
        class EntriesController < Help::Org::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "help"
        end
      end
    end
  end
end
