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

  def redirect_to_base_authority!(path, query: nil)
    redirect_to(
      URI::Generic.build(
        scheme: request.scheme,
        host: base_authority_host,
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
    when /\A(Sign::App|Acme::App)::/ then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    when /\A(Sign::Com|Acme::Com)::/ then ENV.fetch("PRIVATE_AUTH_CORPORATE_URL")
    when /\A(Sign::Org|Acme::Org)::/ then ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    else
      request.host
    end
  end

  def base_authority_host
    case self.class.name
    when /\ASign::App::/ then ENV.fetch("PRIVATE_BASE_SERVICE_URL")
    when /\ASign::Com::/ then ENV.fetch("PRIVATE_BASE_CORPORATE_URL")
    when /\ASign::Org::/ then ENV.fetch("PRIVATE_BASE_STAFF_URL")
    else
      request.host
    end
  end

  def redirect_to_acme_authority!(path, query: nil)
    redirect_to_base_authority!(path, query: query)
  end

  def acme_authority_host
    base_authority_host
  end
end
