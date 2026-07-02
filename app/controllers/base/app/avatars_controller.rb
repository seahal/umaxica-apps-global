# typed: false
# frozen_string_literal: true

module Base
  module App
    # Avatar entity management for the app surface. Plural CRUD over the avatars assigned to the
    # signed-in client; changing the *current* avatar is the switcher's job. Requires a selected
    # actor context (FullAccessController).
    class AvatarsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(Avatar, to: :index?)
        @avatars = switcher.available_avatars
      end

      def show
        @avatar = find_avatar!
        authorize!(@avatar)
      end

      def new
        authorize!(Avatar, to: :create?)
        @avatar = Avatar.new
      end

      def edit
        @avatar = find_avatar!
        authorize!(@avatar)
      end

      def create
        authorize!(Avatar, to: :create?)
        if avatar_params[:moniker].blank?
          @avatar = Avatar.new(avatar_params.except(:handle))
          @avatar.validate
          render :new, status: :unprocessable_content
          return
        end

        @avatar = build_avatar
        if @avatar.save
          @avatar.avatar_assignments.create!(user_id: current_client.id, role: "owner")
          redirect_to(base_app_avatar_path(@avatar.public_id, ri: params[:ri]), status: :see_other)
        else
          render :new, status: :unprocessable_content
        end
      end

      def update
        @avatar = find_avatar!
        authorize!(@avatar)
        if @avatar.update(avatar_params.except(:handle))
          redirect_to(base_app_avatar_path(@avatar.public_id, ri: params[:ri]), status: :see_other)
        else
          render :edit, status: :unprocessable_content
        end
      end

      private

      # Scoped to the principal's assigned avatars: a foreign or non-existent id raises
      # RecordNotFound (404), the authoritative ownership gate for show/edit/update.
      def find_avatar!
        switcher.find_avatar(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end

      def build_avatar
        Avatar.new(
          moniker: avatar_params[:moniker],
          active_handle: create_avatar_handle!,
          capability_id: AvatarCapability::NORMAL,
          client_id: current_client.id,
          owner_organization_id: current_session&.selected_collective_public_id,
          representing_organization_id: current_session&.selected_collective_public_id,
          image_data: {},
        )
      end

      def create_avatar_handle!
        HandleStatus.ensure_defaults! if HandleStatus.respond_to?(:ensure_defaults!)
        Handle.create!(
          handle: avatar_handle,
          handle_status_id: HandleStatus::ACTIVE,
          cooldown_until: Time.current,
          is_system: false,
        )
      end

      def avatar_handle
        base = avatar_params[:handle].presence || avatar_params.fetch(:moniker)
        "#{base.to_s.parameterize.presence || "avatar"}-#{SecureRandom.alphanumeric(8).downcase}"
      end

      def avatar_params
        params.fetch(:avatar, {}).permit(:moniker, :handle)
      end
    end
  end
end
