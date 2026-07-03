# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class FollowsController < SocialGraphController
        def create
          record = AvatarFollow.new(follower_avatar: actor_avatar, followed_avatar: target_avatar)
          authorize_edge!(record, :create)
          render_edge(AvatarSocialGraph::Follow.call(actor_avatar: actor_avatar, target_avatar: target_avatar))
        end

        def destroy
          record = AvatarFollow.find_by!(follower_avatar: actor_avatar, followed_avatar: target_avatar)
          authorize_edge!(record, :destroy)
          AvatarSocialGraph::Unfollow.call(actor_avatar: actor_avatar, target_avatar: target_avatar)
          head :no_content
        end

        private

        def policy_class = AvatarFollowPolicy
      end
    end
  end
end
