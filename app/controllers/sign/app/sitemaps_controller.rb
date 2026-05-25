# typed: false
# frozen_string_literal: true

module Sign
  module App
    class SitemapsController < BareController
      AUTHENTICATION_MODE = :bare

      include ::Sitemap

      def show
        show_xml
      end
    end
  end
end
