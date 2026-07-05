# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class FollowsController < Base::App::FullAccessController
        include BaseAppAvatarSocialGraphActions

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def create
          record = AvatarFollow.new(follower_avatar: actor_avatar, followed_avatar: target_avatar)
          authorize!(record, to: :create?, with: AvatarFollowPolicy, user: actor_avatar)
          render_edge(AvatarSocialGraph::Follow.call(actor_avatar: actor_avatar, target_avatar: target_avatar))
        end

        def destroy
          record = AvatarFollow.find_by!(follower_avatar: actor_avatar, followed_avatar: target_avatar)
          authorize!(record, to: :destroy?, with: AvatarFollowPolicy, user: actor_avatar)
          AvatarSocialGraph::Unfollow.call(actor_avatar: actor_avatar, target_avatar: target_avatar)
          head :no_content
        end
      end
    end
  end
end
