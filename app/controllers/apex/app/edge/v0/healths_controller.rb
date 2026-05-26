# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Edge
      module V0
        class HealthsController < Apex::App::BareController
          include ::Health

          AUTHENTICATION_MODE = :bare

          def show
            show_json
          end
        end
      end
    end
  end
end
