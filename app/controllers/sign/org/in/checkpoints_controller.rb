# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module In
      class CheckpointsController < Sign::Org::PrivateController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :continue_checkpoint_sequence_without_content!
        before_action :guard_timeout, only: %i(show update)

        def show
          @bulletin = current_bulletin
        end

        def update
          refresh_bulletin_dimension!
          redirect_to(sign_org_in_checkpoint_path(pt: path_target_value, ri: params[:ri]))
        end

        def destroy
          pt_param = path_target_value
          consume_bulletin!
          redirect_after_checkpoint_sequence!(pt: pt_param)
        end

        private

        def sign_in_sequence_surface
          :org
        end

        def guard_timeout
          return unless bulletin_expired?

          render plain: I18n.t("sign.org.in.bulletins.timeout"), status: :request_timeout
        end
      end
    end
  end
end
