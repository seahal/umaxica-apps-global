# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class ConfigurationsController < ApplicationController
      auth_required!
      before_action :authenticate_operator!

      def show
      end
    end
  end
end
