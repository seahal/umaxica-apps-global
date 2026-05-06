# typed: false
# frozen_string_literal: true

module Apex
  module App
    class RobotsController < ApplicationController
      include ::Robots

      skip_before_action :canonicalize_query_params, raise: false
      skip_before_action :set_region, raise: false
      public_strict!

      def show
        show_plain_text
      end
    end
  end
end
