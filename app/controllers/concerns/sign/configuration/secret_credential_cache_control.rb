# typed: false
# frozen_string_literal: true

module Sign
  module Configuration
    # Prevents browser / proxy caching of pages that surface raw secret_credential material
    # (e.g. the `new` form shows the freshly-generated raw secret_credential once). Without
    # `no-store`, hitting Back or sharing a snapshot can resurrect the plaintext.
    module SecretCredentialCacheControl
      extend ActiveSupport::Concern

      private

      def set_no_store_for_secret_credential_pages
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
      end
    end
  end
end
