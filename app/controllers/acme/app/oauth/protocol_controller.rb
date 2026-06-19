# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Oauth
      class ProtocolController < Acme::App::BareController
        TRUSTED_BROWSER_ORIGINS = %w(
          https://www.umaxica.app
          https://sign.umaxica.app
          https://base.umaxica.app
          https://core.umaxica.app
          https://palm.umaxica.app
        ).freeze

        protect_from_forgery using: :header_or_legacy_token,
                             trusted_origins: TRUSTED_BROWSER_ORIGINS,
                             with: :null_session
      end
    end
  end
end
