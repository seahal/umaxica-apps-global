# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SitemapsController < Sign::PublicController
      include ::Sitemap

      public_strict!

      def show
        show_xml
      end
    end
  end
end
