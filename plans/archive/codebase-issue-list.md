# Codebase Issue List - Items Requiring Fixes

## 🔒 Security Concerns

### 1. Database configuration inconsistencies (database.yml)

- Problems:
  - Incorrect environment variable references (lines 100, 113, 140).
  - Wrong migration path (line 140: `specialitys_migrate` → `specialities_migrate`).
- Fix: Correct the environment variables and migration path.

### 2. Insecure cookie settings in development

- Problem: `secure: Rails.env.production? ? true : false` leaves cookies vulnerable on HTTP.
- Fix: Introduce appropriate SSL settings and consider secure cookies in development.

### 3. CSP allows unsafe-inline (content_security_policy.rb:15-16)

- Problem: `:unsafe_inline` is permitted for scripts and styles, opening XSS risk.
- Fix: Remove `unsafe-inline` and use nonce-based CSP.

### 4. Missing strong parameter filtering

- Problem: Controllers are missing strong parameter whitelists.
- Fix: Use the `permit` method to whitelist parameters.

## 🏗 Code Quality and Architecture Issues

### 5. Extremely low test coverage

- Problem: Only 95 tests across more than 17,500 files (~0.5%).
- Fix: Expand coverage, concentrating on security-sensitive modules first.

### 6. Session management concerns (memorize.rb)

- Problem: Custom Redis-based session management risks key collisions.
- Fix: Add proper namespacing and validation for session keys.

### 7. Multi-database architecture is overly complex

- Problem: More than ten separate databases with intricate replica configuration.
- Fix: Consolidate databases where possible or improve configuration management.

## 📋 Recommended Order of Work

1. **Fix database configuration inconsistencies** (avoids replication issues).
2. **Review CSP configuration** (security hardening).
3. **Add tests for key functionality** (strengthens quality assurance).

## 📝 Notes

- These issues directly affect production stability and security.
- Handle security fixes carefully and test thoroughly.

Created: 2025-06-11 Updated: 2026-04-04
