# typed: false
# frozen_string_literal: true

module Help
  module Com
    class RootsController < Help::Com::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end
    end
  end
end
