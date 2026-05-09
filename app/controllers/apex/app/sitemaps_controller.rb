# typed: false
# frozen_string_literal: true

module Apex
  module App
    class SitemapsController < Apex::PublicController
      include ::Sitemap

      public_strict!

      def show
        show_xml
      end
    end
  end
end
