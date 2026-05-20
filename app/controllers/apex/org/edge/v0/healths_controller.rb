# typed: false
# frozen_string_literal: true

module Apex
  module Org
    module Edge
      module V0
        class HealthsController < Apex::Org::BareController
          include ::Health

          def show
            show_json
          end
        end
      end
    end
  end
end
