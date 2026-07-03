# typed: false
# frozen_string_literal: true

module Base
  module App
    class GroupAvatarMembershipsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!
      before_action :set_group
      before_action :set_membership, only: %i(update destroy)

      def create
        avatar = Avatar.find_by!(public_id: membership_params.fetch(:avatar_public_id))
        membership = GroupAvatarMembership.new(avatar_group: @group, avatar: avatar)
        authorize!(membership, to: :create?)

        membership = GroupAvatarMemberships::Attach.call(
          group: @group,
          avatar: avatar,
          role: membership_params[:role].presence || "member",
          position: membership_params[:position],
        )
        render json: { membership: serialize_membership(membership) }, status: :created
      end

      def update
        authorize!(@membership, to: :update?)
        membership = GroupAvatarMemberships::Reorder.call(
          membership: @membership,
          position: membership_params.fetch(:position),
        )
        render json: { membership: serialize_membership(membership) }
      end

      def destroy
        authorize!(@membership, to: :destroy?)
        GroupAvatarMemberships::Detach.call(membership: @membership)
        head :no_content
      end

      private

      def set_group
        @group = AvatarGroup.find_by!(public_id: params[:group_id])
      end

      def set_membership
        @membership = @group.group_avatar_memberships.find_by!(public_id: params[:id])
      end

      def membership_params
        params.require(:membership).permit(:avatar_public_id, :role, :position)
      end

      def serialize_membership(membership)
        {
          public_id: membership.public_id,
          group_public_id: membership.avatar_group.public_id,
          avatar_public_id: membership.avatar.public_id,
          role: membership.role,
          position: membership.position,
          state: membership.state,
        }
      end
    end
  end
end
