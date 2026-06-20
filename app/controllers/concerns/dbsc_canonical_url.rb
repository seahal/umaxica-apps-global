# typed: false
# frozen_string_literal: true

# DBSC registration/refresh paths and audiences are a device-binding contract, not
# ordinary navigation URLs. The browser registers a session against the advertised
# `path` and then every proof JWT's `aud` claim must match the endpoint exactly
# (see DbscProofValidator#validate_claims, which rejects on `audience_mismatch`).
#
# PreferenceGlobal#default_url_options merges per-request context params
# (ri/lx/tz/ct/cu/...) into every generated URL. Left unstripped, the DBSC `path`
# and `aud` would drift between the registration request and a later refresh request
# whenever those params differ (e.g. a region switch jp -> us), silently breaking the
# bound-session refresh. DBSC URLs must therefore be canonical: same value every time,
# independent of request context.
module DbscCanonicalUrl
  extend ActiveSupport::Concern

  private

  # Returns the URL with any query string removed. Accepts absolute URLs and paths.
  def dbsc_canonical_url(url)
    return url if url.blank?

    parsed = URI.parse(url)
    parsed.query = nil
    parsed.fragment = nil
    parsed.to_s
  rescue URI::InvalidURIError
    url.to_s.split("?", 2).first
  end
end
