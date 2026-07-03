# typed: false
# frozen_string_literal: true

module Base
  module App
    module Avatars
      class SocialGraphController < Base::App::FullAccessController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!

        private

        def actor_avatar
          @actor_avatar ||= Avatar.find_by!(public_id: Actor.selection.avatar_public_id)
        end

        def target_avatar
          @target_avatar ||= Avatar.find_by!(public_id: params.fetch(:avatar_id))
        end

        def render_edge(edge)
          render json: { public_id: edge.id.to_s }, status: :created
        end

        def authorize_edge!(record, action)
          policy = policy_class.new(record, user: actor_avatar)
          return if policy.public_send("#{action}?")

          raise ActionPolicy::Unauthorized.new(policy, action)
        end
      end
    end
  end
end
