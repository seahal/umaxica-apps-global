# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module In
        class ChecksController < ::Sign::Com::In::CheckpointsController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          def self.local_prefixes = ["sign/com/in/checkpoints"] + super
        end
      end
    end
  end
end
