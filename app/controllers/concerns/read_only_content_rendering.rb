# typed: false
# frozen_string_literal: true

module ReadOnlyContentRendering
  extend ActiveSupport::Concern

  private

  def render_content_index
    @content_entries = content_entry_class.published.for_locale(content_locale).recent_first

    respond_to do |format|
      format.html { render "shared/content_entries/index" }
      format.json { render json: public_content_entries_json }
    end
  end

  def render_content_show
    @content_entry = content_entry_class.published.for_locale(content_locale).find_by!(slug: params.expect(:id))

    respond_to do |format|
      format.html { render "shared/content_entries/show" }
      format.json { render json: public_content_entry_json(@content_entry) }
    end
  end

  def render_content_api_index
    @content_entries = content_entry_class.published.for_locale(content_locale).recent_first
    render json: { entries: public_content_entries_json }
  end

  def render_content_api_show
    entry = content_entry_class.published.for_locale(content_locale).find_by!(slug: params.expect(:id))
    render json: { entry: public_content_entry_json(entry) }
  end

  def public_content_entries_json
    @content_entries.map { |entry| public_content_entry_json(entry) }
  end

  def public_content_entry_json(entry)
    entry.as_public_json(namespace: content_namespace, surface: content_surface)
  end

  def content_entry_class
    @content_entry_class ||= [
      content_namespace.to_s.camelize,
      content_surface.to_s.camelize,
      "ContentEntry",
    ].join("::").constantize
  end

  def content_namespace
    self.class.name.deconstantize.split("::").first.underscore
  end

  def content_surface
    self.class.name.deconstantize.split("::").second.underscore
  end

  def content_locale
    params[:locale].presence || params[:ri].presence || I18n.locale.to_s
  end
end
