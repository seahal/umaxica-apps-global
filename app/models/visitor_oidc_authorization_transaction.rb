# typed: false
# frozen_string_literal: true

class VisitorOidcAuthorizationTransaction < ComTicketRecord
  include OidcAuthorizationTransactionable
  oidc_authorization_surface "com"
end
