# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class BlocksController < Base::App::FullAccessController
        include BaseAppAvatarSocialGraphActions

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def create
          record = AvatarBlock.new(blocker_avatar: actor_avatar, blocked_avatar: target_avatar)
          authorize!(record, to: :create?, with: AvatarBlockPolicy, context: { user: actor_avatar })
          render_edge(AvatarSocialGraph::Block.call(actor_avatar: actor_avatar, target_avatar: target_avatar))
        end

        def destroy
          record = AvatarBlock.find_by!(blocker_avatar: actor_avatar, blocked_avatar: target_avatar)
          authorize!(record, to: :destroy?, with: AvatarBlockPolicy, context: { user: actor_avatar })
          AvatarSocialGraph::Unblock.call(actor_avatar: actor_avatar, target_avatar: target_avatar)
          head :no_content
        end
      end
    end
  end
end
