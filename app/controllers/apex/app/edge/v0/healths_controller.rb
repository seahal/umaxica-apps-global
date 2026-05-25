# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Edge
      module V0
        class HealthsController < Apex::App::BareController
          AUTHENTICATION_MODE = :bare

          include ::Health

          def show
            show_json
          end
        end
      end
    end
  end
end
