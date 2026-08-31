# typed: false
# frozen_string_literal: true

# Keeps the legacy `.../removal` POST endpoints working by sending the browser to the
# resource's canonical settings page on the surface it is already browsing.
#
# The host used to be chosen by matching the controller's namespace against `Sign::`
# and `Acme::`. Those namespaces became `Auth::` and `Base::`, so the match stopped
# firing and every call fell through to `request.host`. Every remaining caller is a
# removals controller redirecting within its own surface, which is exactly
# `request.host`, so the selection is now written out rather than left as branches
# that cannot be taken. Cross-surface hops belong to SignAcmeAuthorityRedirect, whose
# patterns were updated for the rename.
module SignAuthorityRedirect
  extend ActiveSupport::Concern

  private

  def redirect_to_sign_authority!(path, query: nil)
    redirect_to(
      URI::Generic.build(
        scheme: request.scheme,
        host: request.host,
        path: path,
        query: sign_authority_query(query),
      ).to_s,
      allow_other_host: cross_host_redirect_allowed?,
      status: :see_other,
    )
  end

  def sign_authority_query(query_params = nil)
    return query_params.to_query if query_params.present?

    ri = params[:ri].presence
    return if ri.blank?

    { ri: ri }.to_query
  end
end
