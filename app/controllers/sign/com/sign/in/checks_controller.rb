# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module In
        class ChecksController < ::Sign::Com::ApplicationController
          include SignComInCheckControllerSupport

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_visitor!
          before_action :continue_checkpoint_sequence_without_content!
          before_action :guard_timeout, only: %i(show update)

          def self.local_prefixes
            ["sign/com/in/checkpoints"] + super
          end

          def show = super

          def update = super
        end
      end
    end
  end
end
