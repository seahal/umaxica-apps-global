# typed: false
# frozen_string_literal: true

module Sign
  module SettingsAuthorityRedirect
    extend ActiveSupport::Concern
    include ::Sign::AcmeAuthorityRedirect

    def show = redirect_to_acme_settings_authority!

    def index = redirect_to_acme_settings_authority!

    def edit = redirect_to_acme_settings_authority!

    def update = redirect_to_acme_settings_authority!

    def destroy = redirect_to_acme_settings_authority!

    private

    # sign/id keeps this URL only as a compatibility redirect.
    def redirect_to_acme_settings_authority!
      redirect_to_acme_authority!(request.path, query: request.query_parameters)
    end
  end
end
