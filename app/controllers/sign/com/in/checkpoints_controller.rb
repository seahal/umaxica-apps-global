# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class CheckpointsController < PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        before_action :continue_checkpoint_sequence_without_content!
        before_action :guard_timeout, only: %i(show update)

        def show
          @bulletin = current_bulletin
        end

        def update
          refresh_bulletin_dimension!
          redirect_to(sign_com_in_checkpoint_path(rt: redirect_parameter_value, ri: params[:ri]))
        end

        def destroy
          rt_param = redirect_parameter_value
          consume_bulletin!
          redirect_after_checkpoint_sequence!(rt: rt_param)
        end

        private

        def sign_in_sequence_surface
          :com
        end

        def guard_timeout
          return unless bulletin_expired?

          render plain: I18n.t("sign.app.in.bulletins.timeout"), status: :request_timeout
        end
      end
    end
  end
end
