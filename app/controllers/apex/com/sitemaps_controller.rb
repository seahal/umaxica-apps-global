# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class SitemapsController < BareController
      include ::Sitemap

      def show
        show_xml
      end
    end
  end
end
