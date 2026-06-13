# typed: false
# frozen_string_literal: true

module Docs
  module App
    class RootsController < Docs::App::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end
    end
  end
end
