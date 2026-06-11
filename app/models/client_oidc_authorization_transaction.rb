# typed: false
# frozen_string_literal: true

class ClientOidcAuthorizationTransaction < AppTicketRecord
  include OidcAuthorizationTransactionable
  oidc_authorization_surface "app"
end
