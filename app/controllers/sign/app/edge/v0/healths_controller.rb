# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Edge
      module V0
        class HealthsController < ApplicationController
          include ::Health

          skip_before_action :canonicalize_query_params, raise: false
          skip_before_action :set_region, raise: false
          public_strict!

          def show
            show_json
          end
        end
      end
    end
  end
end
