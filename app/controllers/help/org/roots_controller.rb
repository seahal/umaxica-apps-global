# typed: false
# frozen_string_literal: true

module Help
  module Org
    class RootsController < Help::Org::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end
    end
  end
end
