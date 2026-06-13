# typed: false
# frozen_string_literal: true

module Help
  module App
    class EntriesController < Help::App::BareController
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
