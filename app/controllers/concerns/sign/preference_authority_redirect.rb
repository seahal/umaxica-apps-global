# typed: false
# frozen_string_literal: true

module Sign
  module PreferenceAuthorityRedirect
    extend ActiveSupport::Concern
    include ::Sign::AcmeAuthorityRedirect

    def show = redirect_to_acme_preference_authority!

    def edit = redirect_to_acme_preference_authority!

    def update = redirect_to_acme_preference_authority!

    def destroy = redirect_to_acme_preference_authority!

    private

    # Preference authority belongs to acme/www.
    def redirect_to_acme_preference_authority!
      redirect_to_acme_authority!(request.path, query: request.query_parameters)
    end
  end
end
