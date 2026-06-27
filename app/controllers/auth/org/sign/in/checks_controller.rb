# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        class ChecksController < ::Auth::Org::ApplicationController
          include SignOrgInCheckControllerSupport

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_operator!
          before_action :continue_checkpoint_sequence_without_content!
          before_action :guard_timeout, only: %i(show update)

          def show = super

          def update = super
        end
      end
    end
  end
end
