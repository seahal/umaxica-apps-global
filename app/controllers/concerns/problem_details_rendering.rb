# typed: false
# frozen_string_literal: true

# Renders RFC 9457 Problem Details as `application/problem+json`.
#
# This is the single error renderer for non-protocol JSON API endpoints. It replaces the duplicated
# `render_error` implementations that previously lived in CoreBrowserApiBoundary and in the Palm API
# base controller, and the several bare `{ error: "..." }` shapes elsewhere.
#
# The document carries only the members RFC 9457 defines plus the two extension members this
# repository has agreed to (`request_id`, and `errors` on 422). Anything else requires amending
# docs/reference/api-design-standards.md first.
#
# Endpoints whose format is fixed by their own specification -- OAuth, OIDC, WebAuthn, DBSC, MCP
# JSON-RPC, health, `.well-known` -- must not use this concern. See
# adr/api-error-format-problem-details.md.
module ProblemDetailsRendering
  extend ActiveSupport::Concern

  CONTENT_TYPE = "application/problem+json"

  private

  # `status` is not a parameter: it comes from the registry, so the status line and the `status`
  # member cannot drift apart, and one type cannot answer with two different codes.
  def render_problem(slug, detail: nil, errors: [])
    problem = ProblemType.fetch(slug)

    render(
      json: problem_document(problem, detail: detail, errors: errors),
      status: problem.status,
      content_type: CONTENT_TYPE,
    )
  end

  # Overridable so a boundary with an external consumer can add a transitional member during a
  # migration. Overrides must call `super` and merge, never rebuild the document.
  def problem_document(problem, detail:, errors:)
    document = {
      type: problem.uri,
      title: problem.title,
      status: problem.status_code,
      instance: request.path,
      request_id: request.request_id,
    }
    # RFC 9457 3.1.4: `detail` is occurrence-specific and aimed at a human. Omitted rather than null
    # when there is nothing occurrence-specific to say.
    document[:detail] = detail if detail.present?
    # Validation pointers are only meaningful for 422; emitting an empty list on every other status
    # would invite clients to branch on its presence.
    document[:errors] = errors if errors.present?
    document
  end
end
