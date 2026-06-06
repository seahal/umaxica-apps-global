# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      module In
        class PasskeysController < ::Sign::Com::In::PasskeysController
          AUTHENTICATION_MODE = :guest
          declare_authentication_mode! :guest

          def self.local_prefixes = ["sign/com/in/passkeys"] + super
        end
      end
    end
  end
end
