# typed: false
# frozen_string_literal: true

module Acme
  module App
    # Avatar entity management for the app surface. Plural CRUD over the avatars assigned to the
    # signed-in client; changing the *current* avatar is the switcher's job. Requires a selected
    # actor context (FullAccessController).
    class AvatarsController < Acme::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        @avatars = switcher.available_avatars
      end

      def show
        @avatar = find_avatar!
        authorize!(current_client, to: :show?)
      end

      def new
        authorize!(current_client, to: :update?)
      end

      def edit
        @avatar = find_avatar!
        authorize!(current_client, to: :update?)
      end

      def create
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_avatars_path(ri: params[:ri]), status: :see_other)
      end

      def update
        @avatar = find_avatar!
        authorize!(current_client, to: :update?)
        redirect_to(acme_app_avatar_path(@avatar.public_id, ri: params[:ri]), status: :see_other)
      end

      private

      # Scoped to the principal's assigned avatars: a foreign or non-existent id raises
      # RecordNotFound (404), the authoritative ownership gate for show/edit/update.
      def find_avatar!
        switcher.find_avatar(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= AcmeSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end
    end
  end
end
