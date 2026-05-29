# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Edge
      module V0
        class HealthsController < Acme::Com::BareController
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
