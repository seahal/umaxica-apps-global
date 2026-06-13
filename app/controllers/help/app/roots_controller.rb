# typed: false
# frozen_string_literal: true

module Help
  module App
    class RootsController < Help::App::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end
    end
  end
end
