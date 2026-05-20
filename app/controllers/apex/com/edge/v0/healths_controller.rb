# typed: false
# frozen_string_literal: true

module Apex
  module Com
    module Edge
      module V0
        class HealthsController < Apex::Com::BareController
          include ::Health

          def show
            show_json
          end
        end
      end
    end
  end
end
