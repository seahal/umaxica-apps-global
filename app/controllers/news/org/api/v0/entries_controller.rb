# typed: false
# frozen_string_literal: true

module News
  module Org
    module Api
      module V0
        class EntriesController < News::Org::BareController
          include ::SurfaceEntriesRendering

          AUTHENTICATION_MODE = :bare
          PUBLISHING_AUDIENCE = "org"
          PUBLISHING_SURFACE = "news"
        end
      end
    end
  end
end
