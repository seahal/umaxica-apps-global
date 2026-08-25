# typed: false
# frozen_string_literal: true

# Flipper actor for a registered OIDC relying party.
#
# Flipper resolves actor gates through `flipper_id`, and a bare String is not a
# valid actor: it would be gated as whatever `to_s` happens to produce, with no
# namespace separating a client id from any other identifier that might later be
# used as an actor. `OidcClientRegistry` represents `client_id` as a plain
# String (see OidcClientRegistry::VisitorAccount), so this wrapper is built at
# the gate rather than threaded through job arguments -- the job's serialized
# argument stays a String.
OidcClientFlipperActor =
  Data.define(:client_id) do
    def flipper_id = "oidc_client;#{client_id}"
  end
