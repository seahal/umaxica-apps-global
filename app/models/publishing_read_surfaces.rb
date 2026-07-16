# typed: false
# frozen_string_literal: true

# Which content surfaces (docs/news/help) currently read from the central
# publishing DB instead of the legacy per-audience lean tables. Controlled by
# PUBLISHING_READ_SURFACES, a comma-separated surface list. No env var means
# no surface has cut over yet -- an explicit, documented default, not a
# silent fallback. Info always reads from publishing (see
# adr/publishing-db-content-authority.md) and is not gated by this flag.
module PublishingReadSurfaces
  module_function

  def enabled?(surface)
    configured_surfaces.include?(surface.to_s)
  end

  def configured_surfaces
    ENV.fetch("PUBLISHING_READ_SURFACES", "").split(",").map(&:strip).compact_blank.to_set
  end
end
