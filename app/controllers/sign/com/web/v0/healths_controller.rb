# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Web
      module V0
        class HealthsController < Sign::Com::BareController
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
