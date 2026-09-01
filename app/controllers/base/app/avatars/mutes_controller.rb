# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class MutesController < Base::App::FullAccessController
        include BaseAppAvatarSocialGraphActions

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        def create
          record = AvatarMute.new(muter_avatar: actor_avatar, muted_avatar: target_avatar)
          authorize!(record, to: :create?, with: AvatarMutePolicy, context: { user: actor_avatar })
          render_edge(AvatarSocialGraph::Mute.call(actor_avatar: actor_avatar, target_avatar: target_avatar))
        end

        def destroy
          record = AvatarMute.find_by!(muter_avatar: actor_avatar, muted_avatar: target_avatar)
          authorize!(record, to: :destroy?, with: AvatarMutePolicy, context: { user: actor_avatar })
          AvatarSocialGraph::Unmute.call(actor_avatar: actor_avatar, target_avatar: target_avatar)
          head :no_content
        end
      end
    end
  end
end
