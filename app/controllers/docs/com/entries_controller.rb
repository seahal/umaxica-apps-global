# typed: false
# frozen_string_literal: true

module Docs
  module Com
    class EntriesController < Docs::Com::BareController
      include ::ReadOnlyContentRendering

      AUTHENTICATION_MODE = :bare

      def index
        render_content_index
      end

      def show
        render_content_show
      end
    end
  end
end
