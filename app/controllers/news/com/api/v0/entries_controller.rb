# typed: false
# frozen_string_literal: true

module News
  module Com
    module Api
      module V0
        class EntriesController < News::Com::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "com"
          PUBLISHING_SURFACE = "news"
        end
      end
    end
  end
end
