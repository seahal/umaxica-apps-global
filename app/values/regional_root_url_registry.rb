# typed: false
# frozen_string_literal: true

# The explicit allowlist of canonical regional root URLs the `www` gateway hosts redirect to.
#
# `www.umaxica.{app,com,org}` carries the region in the `ri` query parameter rather than in the
# hostname. These entries are the canonical regional hostnames that replace it, one permanent
# destination per surface and region.
#
# The destinations are literals, never interpolated from request input: a request that does not
# match an entry exactly resolves to nil and no redirect happens. `jp.umaxica.*` is the canonical
# Core host family decided in `adr/core-canonical-public-host.md`; `us.umaxica.*` is the matching
# family for the `us` region. Both are served by the edge, not by this application, so they are
# absolute URLs and their redirects are cross-host.
#
# The region keys must stay identical to `RequestContextContract::ALLOWED_REGIONS`.
# `RegionalRootUrlRegistryTest` fails when the two drift apart.
module RegionalRootUrlRegistry
  URLS = {
    app: {
      "jp" => "https://jp.umaxica.app/",
      "us" => "https://us.umaxica.app/",
    }.freeze,
    com: {
      "jp" => "https://jp.umaxica.com/",
      "us" => "https://us.umaxica.com/",
    }.freeze,
    org: {
      "jp" => "https://jp.umaxica.org/",
      "us" => "https://us.umaxica.org/",
    }.freeze,
  }.freeze

  SURFACES = URLS.keys.freeze

  module_function

  # @param surface [Symbol] one of `SURFACES`
  # @param region [String, nil] the raw `ri` request parameter
  # @return [String, nil] the trusted canonical root URL, or nil when the region is not allowlisted.
  #   An unknown region resolves to nil rather than to a default, so no caller can turn an
  #   unrecognized `ri` into a redirect.
  def url_for(surface:, region:)
    URLS.fetch(surface).fetch(region.to_s, nil)
  end
end
