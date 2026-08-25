# typed: false
# frozen_string_literal: true

# Shared rendering for revision endpoints. The deployment identifier comes only
# from the official Rails application revision, so no endpoint reads Git, the
# filesystem, or the environment itself.
module ApplicationRevisionRendering
  extend ActiveSupport::Concern

  # Deployment identifier response. No database, cache, or external dependency
  # is touched; a missing revision is a normal 200 with a null value.
  def render_revision
    response.set_header("Cache-Control", "no-store")
    response.set_header("X-Robots-Tag", "noindex, nofollow")

    render json: { revision: Rails.application.revision&.to_s }
  end
end
