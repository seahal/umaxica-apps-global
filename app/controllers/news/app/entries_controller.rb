# typed: false
# frozen_string_literal: true

module News
  module App
    class EntriesController < News::App::BareController
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
