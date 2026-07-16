# typed: false
# frozen_string_literal: true

# Docs/News/Help entries controllers read from the legacy lean content-entry
# tables until their surface is switched over via PublishingReadSurfaces, then
# from the central publishing DB. Each including controller must declare
# PUBLISHING_AUDIENCE (app/com/org) and PUBLISHING_SURFACE (docs/news/help).
# See plans/publishing-db-valiant-moore.md Phase 6.
module SurfaceEntriesRendering
  extend ActiveSupport::Concern

  include ReadOnlyContentRendering
  include PublishingContentRendering

  def index
    publishing_surface_enabled? ? render_publishing_entries_index : render_content_api_index
  end

  def show
    publishing_surface_enabled? ? render_publishing_entry_show : render_content_api_show
  end

  private

  def publishing_surface_enabled?
    PublishingReadSurfaces.enabled?(self.class::PUBLISHING_SURFACE)
  end
end
