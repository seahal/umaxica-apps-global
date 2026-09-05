# typed: false
# frozen_string_literal: true

# Staff Publishing CMS HTTP actions for one surface/audience cell.
#
# Contract: the including controller declares PUBLISHING_AUDIENCE,
# PUBLISHING_SURFACE, and ENTRY_CLASS as explicit constants. Those values are
# never inferred from the class name, request path, params, or host.
#
# A management URL has no locale segment. Index and show therefore cover every
# Entry whose Edition matches the declared audience and surface, across locales.
module PublishingManagementEntriesActions
  extend ActiveSupport::Concern

  include ::SurfaceInertiaPage

  class_methods do
    def publishing_audience
      unless const_defined?(:PUBLISHING_AUDIENCE, false)
        raise(NameError, "#{name} must declare PUBLISHING_AUDIENCE")
      end

      const_get(:PUBLISHING_AUDIENCE, false)
    end

    def publishing_surface
      unless const_defined?(:PUBLISHING_SURFACE, false)
        raise(NameError, "#{name} must declare PUBLISHING_SURFACE")
      end

      const_get(:PUBLISHING_SURFACE, false)
    end

    def publishing_entry_class
      unless const_defined?(:ENTRY_CLASS, false)
        raise(NameError, "#{name} must declare ENTRY_CLASS")
      end

      const_get(:ENTRY_CLASS, false)
    end
  end

  included do
    # Bare CMS pages inherit RateLimit but no default quota. Declare the same
    # surface web baseline ApplicationController uses so unauthenticated local
    # access is still bounded.
    rate_limit(
      to: 300,
      within: 1.minute,
      by: -> { request.remote_ip },
      scope: "base_org_publishing_management_web",
      name: "publishing_management_web",
      store: rate_limit_store,
      with: -> { render_rate_limited(retry_after: 60) },
    )
  end

  def index
    entries = publishing_entries_query.call.map { |entry| index_entry_props(entry) }
    render inertia: true, props: {
      title: management_title,
      description: "Entries for #{publishing_surface}/#{publishing_audience} across locales.",
      surface: publishing_surface,
      audience: publishing_audience,
      entries:,
    }
  end

  def show
    entry = find_management_entry!
    render inertia: true, props: show_entry_props(entry)
  end

  def edit
    entry = find_management_entry!
    render inertia: true, props: edit_entry_props(entry, errors: {})
  end

  def update
    entry = find_management_entry!
    form = Publishing::ReviseEntryForm.new(revise_entry_form_attributes)

    unless form.valid?
      render_edit_failure(entry, errors: form_error_hash(form), form: form)
      return
    end

    result = Publishing::ReviseEntryOperation.call(
      entry:,
      title: form.title,
      summary: form.summary,
      body: form.parsed_body,
      lock_version: form.lock_version,
    )

    unless result.ok?
      render_edit_failure(entry.reload, errors: result.errors, form: form)
      return
    end

    redirect_to({ action: :show, id: entry.public_id }, status: :see_other)
  end

  private

  def publishing_audience
    self.class.publishing_audience
  end

  def publishing_surface
    self.class.publishing_surface
  end

  def publishing_entries_query
    PublishingManagementEntriesQuery.new(entry_class: self.class.publishing_entry_class)
  end

  def find_management_entry!
    publishing_entries_query.find!(public_id: params.expect(:id))
  end

  def revise_entry_form_attributes
    permitted = params.expect(entry: %i(title summary body lock_version))
    {
      title: permitted[:title],
      summary: permitted[:summary],
      body_text: permitted[:body],
      lock_version: permitted[:lock_version],
    }
  end

  def render_edit_failure(entry, errors:, form:)
    render inertia: "#{controller_path}/edit",
           props: edit_entry_props(entry, errors: errors, form: form),
           status: :unprocessable_content
  end

  def form_error_hash(form)
    form.message_hash
  end

  def management_title
    "Publishing #{publishing_surface}/#{publishing_audience}"
  end

  def index_entry_props(entry)
    revision = entry.current_revision
    {
      public_id: entry.public_id,
      title: revision&.title,
      locale: entry.locale,
      canonical_slug: entry.canonical_slug&.slug,
      archive_state: entry.archived? ? "archived" : "active",
      publication_state: entry.active_publication.present? ? "published" : "draft",
      revision_sequence: revision&.sequence,
      updated_at: entry.updated_at&.iso8601,
      show_href: url_for(action: :show, id: entry.public_id, only_path: true),
      edit_href: url_for(action: :edit, id: entry.public_id, only_path: true),
    }
  end

  def show_entry_props(entry)
    revision = entry.current_revision
    {
      title: revision&.title.presence || management_title,
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: url_for(action: :index, only_path: true),
      edit_href: url_for(action: :edit, id: entry.public_id, only_path: true),
      entry: {
        public_id: entry.public_id,
        surface: publishing_surface,
        audience: publishing_audience,
        locale: entry.locale,
        canonical_slug: entry.canonical_slug&.slug,
        current_revision_public_id: revision&.public_id,
        revision_sequence: revision&.sequence,
        title: revision&.title,
        summary: revision&.summary,
        body: revision&.body,
        archive_state: entry.archived? ? "archived" : "active",
        publication_state: entry.active_publication.present? ? "published" : "draft",
        revision_count: entry.revisions.count,
        version_count: entry.versions.count,
        updated_at: entry.updated_at&.iso8601,
      },
    }
  end

  def edit_entry_props(entry, errors:, form: nil)
    revision = entry.current_revision
    body_source = form&.body_text
    body_source ||= pretty_body_json(revision&.body)
    {
      title: "Edit #{revision&.title.presence || entry.public_id}",
      description: "#{publishing_surface}/#{publishing_audience}",
      index_href: url_for(action: :index, only_path: true),
      show_href: url_for(action: :show, id: entry.public_id, only_path: true),
      errors: stringify_error_keys(errors),
      form: {
        action: url_for(action: :update, id: entry.public_id, only_path: true),
        method: "patch",
        title: form&.title || revision&.title,
        summary: form&.summary || revision&.summary,
        body: body_source,
        lock_version: entry.lock_version,
        locale: entry.locale,
        canonical_slug: entry.canonical_slug&.slug,
      },
    }
  end

  def pretty_body_json(body)
    JSON.pretty_generate(body || {})
  end

  def stringify_error_keys(errors)
    errors.to_h { |key, value| [key.to_s, value] }
  end
end
