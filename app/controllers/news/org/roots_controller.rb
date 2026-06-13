# typed: false
# frozen_string_literal: true

module News
  module Org
    class RootsController < News::Org::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end
    end
  end
end
