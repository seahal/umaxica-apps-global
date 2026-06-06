# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module In
        class ChecksController < ::Sign::App::In::CheckpointsController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          def self.local_prefixes = ["sign/app/in/checkpoints"] + super
        end
      end
    end
  end
end
