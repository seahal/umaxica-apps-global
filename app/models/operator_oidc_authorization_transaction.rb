# typed: false
# frozen_string_literal: true

class OperatorOidcAuthorizationTransaction < OrgTicketRecord
  include OidcAuthorizationTransactionable
  oidc_authorization_surface "org"
end
