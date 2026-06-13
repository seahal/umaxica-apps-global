# typed: false
# frozen_string_literal: true

module Docs
  module Com
    class RootsController < Docs::Com::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end
    end
  end
end
