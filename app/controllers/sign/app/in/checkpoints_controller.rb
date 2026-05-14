# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      class CheckpointsController < Sign::App::ApplicationController
        auth_required!
        before_action :authenticate_user!
        before_action :maybe_inject_test_bulletin!
        before_action :continue_checkpoint_sequence_without_content!
        before_action :guard_timeout, only: %i(show update)

        def show
          @bulletin = current_bulletin
        end

        def update
          refresh_bulletin_dimension!
          safe_redirect_to(
            sign_app_in_checkpoint_path(rt: redirect_parameter_value, ri: params[:ri]),
            fallback: sign_app_in_checkpoint_path(ri: params[:ri]),
          )
        end

        def destroy
          rt_param = redirect_parameter_value
          consume_bulletin!
          redirect_after_checkpoint_sequence!(rt: rt_param)
        end

        private

        def guard_timeout
          return unless bulletin_expired?

          render plain: I18n.t("sign.app.in.bulletins.timeout"), status: :request_timeout
        end
      end
    end
  end
end
