# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      class CheckpointsController < Sign::App::PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :continue_checkpoint_sequence_without_content!
        before_action :guard_timeout, only: %i(show update)

        def show
          @bulletin = current_bulletin
        end

        def update
          return unless require_sign_in_sequence_participant!(
            participant: :checkpoint,
            policy_rule: :update_checkpoint?,
          )

          refresh_bulletin_dimension!
          safe_redirect_to(
            sign_app_in_checkpoint_path(pt: signed_pt_param, ri: params[:ri]),
            fallback: sign_app_in_checkpoint_path(ri: params[:ri]),
          )
        end

        def destroy
          return unless require_sign_in_sequence_participant!(
            participant: :checkpoint,
            policy_rule: :destroy_checkpoint?,
          )

          pt_param = signed_pt_param
          consume_bulletin!
          redirect_after_checkpoint_sequence!(pt: pt_param)
        end

        private

        def sign_in_sequence_required_for_participant?(participant)
          participant.to_sym == :checkpoint
        end

        def sign_in_sequence_surface
          :app
        end

        def guard_timeout
          return unless bulletin_expired?

          render plain: I18n.t("sign.app.in.bulletins.timeout"), status: :request_timeout
        end
      end
    end
  end
end
