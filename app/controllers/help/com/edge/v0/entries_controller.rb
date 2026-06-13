# typed: false
# frozen_string_literal: true

module Help
  module Com
    module Edge
      module V0
        class EntriesController < Help::Com::BareController
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
