# typed: false
# frozen_string_literal: true

# Transitional: repeats the pre-RFC-9457 error object inside the Problem Details document.
#
# `/api/v0` is consumed by clients outside this repository -- the Next.js edge application
# (docs/operations/core-nextjs-zero-cookie-edge-contract.md) and the native Palm client -- so the
# error body cannot change in one step. Including this concern keeps the response body backward
# compatible while the media type moves to `application/problem+json`; a consumer that reads the body
# is unaffected, and only a consumer asserting on `Content-Type` must change.
#
# The mapping reproduces the previous body exactly: the legacy `message` carried the sentence that
# RFC 9457 puts in `detail` when it is occurrence-specific and in `title` otherwise, and the legacy
# `detail` was always null.
#
# Remove this file, and the two `include` lines that reference it, once the external consumers have
# migrated. That removal is the final step of adr/api-error-format-problem-details.md and requires
# `Deprecation` and `Sunset` announcement first.
module ApiV0LegacyErrorMember
  extend ActiveSupport::Concern

  private

  def problem_document(problem, detail:, errors:)
    super.merge(
      error: {
        code: problem.slug.to_s,
        message: detail.presence || problem.title,
        request_id: request.request_id,
        detail: nil,
        fields: errors,
      },
    )
  end
end
