# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module In
        class ChecksController < ::Sign::Org::In::CheckpointsController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          def self.local_prefixes = ["sign/org/in/checkpoints"] + super
        end
      end
    end
  end
end
