# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      module In
        class PasskeysController < ::Sign::App::In::PasskeysController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def self.local_prefixes = ["sign/app/in/passkeys"] + super
        end
      end
    end
  end
end
