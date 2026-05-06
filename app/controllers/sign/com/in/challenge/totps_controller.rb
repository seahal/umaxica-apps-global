# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      module Challenge
        class TotpsController < ApplicationController
          before_action :redirect_unavailable!

          def new
          end

          def create
          end

          private

          def redirect_unavailable!
            clear_pending_mfa! if respond_to?(:clear_pending_mfa!, true)
            redirect_to(
              new_sign_com_in_path(ri: params[:ri]),
              alert: I18n.t("auth.step_up.method_unavailable"),
              status: :see_other,
            )
          end
        end
      end
    end
  end
end
