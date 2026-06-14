# typed: false
# frozen_string_literal: true

module Help
  module App
    module Api
      module V0
        class EntriesController < Help::App::BareController
          include ::ReadOnlyContentRendering

          AUTHENTICATION_MODE = :bare

          def index
            render_content_api_index
          end

          def show
            render_content_api_show
          end
        end
      end
    end
  end
end
