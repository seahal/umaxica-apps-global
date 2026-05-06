# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SitemapsController < ApplicationController
      include ::Sitemap

      skip_before_action :canonicalize_query_params, raise: false
      skip_before_action :set_region, raise: false
      public_strict!

      def show
        show_xml
      end
    end
  end
end
