# typed: false
# frozen_string_literal: true

module Base
  module App
    # Group resource surface for Avatar containers. Read-only index only for now.
    class GroupsController < Base::App::FullAccessController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
      end
    end
  end
end
