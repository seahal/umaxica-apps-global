# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      # In-progress state for the /sign/in/email flow on the app surface.
      #
      # The address-submission POST forks into two paths, and a later OTP
      # verify must reconstitute that fork without leaking whether the
      # submitted address exists:
      #
      # - existing path: a ClientEmail was found and the underlying
      #   account is login-allowed. id is stashed; the OTP verify runs
      #   the real path.
      # - dummy path: no usable account. Only the address is stashed so
      #   the timing-attack dummy verify on update has something to echo
      #   back; no OTP is actually sent.
      #
      # The two paths previously used separate top-level session keys
      # (:user_email_authentication_id / :user_email_authentication_address)
      # whose mutual-exclusion invariant was implicit. This wraps the
      # state behind a single session entry so the contract is explicit
      # and consumers cannot accidentally read a stale half.
      class EmailAuthenticationState
        SESSION_KEY = :sign_app_in_email_authentication

        def self.load(session)
          raw = session[SESSION_KEY]
          return nil if raw.blank?

          new(id: raw["id"], address: raw["address"])
        end

        def self.store_existing!(session, email)
          session[SESSION_KEY] = { "id" => email.id, "address" => nil }
        end

        def self.store_dummy!(session, address)
          session[SESSION_KEY] = { "id" => nil, "address" => address.to_s }
        end

        def self.clear!(session)
          session.delete(SESSION_KEY)
        end

        def initialize(id:, address:)
          @id = id
          @address = address
        end

        attr_reader :id, :address

        def existing?
          @id.present?
        end

        def dummy?
          !existing?
        end
      end
    end
  end
end
