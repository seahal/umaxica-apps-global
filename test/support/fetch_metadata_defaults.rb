# frozen_string_literal: true

# Integration requests carry the fetch metadata a browser would send.
#
# Rails 8.2 verifies request forgery from Sec-Fetch-Site first and falls back to
# the authenticity token only when the header is absent
# (ActionController::RequestForgeryProtection#verified_with_legacy_token?). Every
# browser that can reach these surfaces sends the header, so a test request
# without one is not a realistic request: it exercises the legacy fallback and
# leaves the actual protection untested.
#
# Requests made by the application to itself are same-origin, so that is the
# default. A test that means to simulate another site has to say so explicitly:
#
#   post "/social/google", headers: { "Sec-Fetch-Site" => "cross-site" }
#
# which is exactly what the login CSRF guard in
# test/integration/social_ceremony_entry_contract_test.rb does.
module FetchMetadataDefaults
  HEADER = "Sec-Fetch-Site"
  RACK_HEADER = "HTTP_SEC_FETCH_SITE"
  DEFAULT = "same-origin"

  def process(method, path, **kwargs)
    headers = kwargs[:headers]

    unless headers&.key?(HEADER) || headers&.key?(RACK_HEADER)
      kwargs[:headers] = (headers || {}).merge(HEADER => DEFAULT)
    end

    super
  end
end

ActionDispatch::Integration::Session.prepend(FetchMetadataDefaults)
