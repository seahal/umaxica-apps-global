# typed: false
# frozen_string_literal: true

module SignAuthorityRedirect
  extend ActiveSupport::Concern

  private

  def redirect_to_sign_authority!(path, query: nil)
    redirect_to(
      URI::Generic.build(
        scheme: request.scheme,
        host: sign_authority_host,
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

  def sign_authority_host
    case self.class.name
    when /\A(Sign::App|Acme::App)::/ then ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    when /\A(Sign::Com|Acme::Com)::/ then ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    when /\A(Sign::Org|Acme::Org)::/ then ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    else
      request.host
    end
  end
end
