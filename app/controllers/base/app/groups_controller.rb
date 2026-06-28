# typed: false
# frozen_string_literal: true

module Base
  module App
    # Group resource surface for Avatar containers. Read-only index only for now.
    class GroupsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      layout "base/app/inertia"

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        render inertia: true, props: { title: "Groups" }
      end
    end
  end
end
