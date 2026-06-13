# typed: false
# frozen_string_literal: true

module Help
  module Org
    class EntriesController < Help::Org::BareController
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
