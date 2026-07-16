# typed: false
# frozen_string_literal: true

module Help
  module Com
    module Api
      module V0
        class EntriesController < Help::Com::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "com"
          PUBLISHING_SURFACE = "help"
        end
      end
    end
  end
end
