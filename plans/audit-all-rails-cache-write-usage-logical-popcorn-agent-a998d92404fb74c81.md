# Rails Cache Audit Plan

## Overview

Searching for indirect cache usage and abstractions hiding Rails.cache in the repository.

## Search Tasks

1. **Pattern 1: Direct cache method calls**
   - Find: cache.write, cache.fetch, cache.read, cache.delete, cache.exist?
   - Find: store.write, store.fetch, store.read, store.delete
   - Follow receiver to determine if Rails.cache or other

2. **Pattern 2: Cache store references**
   - Find: cache_store, solid_cache, SolidCache, ActiveSupport::Cache

3. **Pattern 3: Rails rate_limit macro**
   - Find: rate_limit calls with store: argument
   - Document: file:line, controller/action, limit, period, store arg

4. **Pattern 4: Security service objects**
   - Names containing: ceremony, candidate, nonce, otp, verifier, issuer, registry, policy, gate,
     lockout, throttle, rate_limit, token_store, session_store, challenge, anti_replay, replay_guard
   - For each: determine cache usage, key shape, TTL, stored data

5. **Specific files to inspect**
   - app/services/identity_social_ceremony_candidate_store.rb
   - app/services/jump_rt_issuer.rb
   - app/services/jump_rt_return_policy.rb
   - app/services/jump_rt_return_verifier.rb
   - app/services/oidc_client_registry.rb
   - app/services/oidc_issuer.rb
   - app/services/sign_up_step_gate.rb
   - app/services/social_auth_signup_finalizer.rb
   - app/models/client_totp_credential.rb
   - app/models/actor/configuration.rb
   - app/controllers/concerns/sign_passkey_sign_in_endpoint.rb
   - app/controllers/concerns/sign_social_authentication_endpoint.rb

6. **Configuration files**
   - config/application.rb
   - config/environments/\*.rb
   - config/cache.yml

## Status

Ready to execute systematic searches.
