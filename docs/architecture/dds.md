# Detailed Design Specification

## 1. Purpose

This document translates the high-level boundary model into implementation guidance.

## 2. System Context

The Rails monolith is split into four engines:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

## 3. Module Design

### 3.1 Routing

- Each engine owns its own route file.
- Each engine uses `isolate_namespace`.
- Cross-engine links use native Rails routing proxies.
- Host app links use `main_app`.

### 3.2 Shared Code

| Layer                 | Ownership                                               |
| --------------------- | ------------------------------------------------------- |
| Controllers and views | Engine-specific                                         |
| Models                | Centralized in `app/models`                             |
| Concerns              | Shared in the host app                                  |
| Services              | Shared in the host app unless a later split is required |
| Helpers               | Shared in the host app                                  |

### 3.3 Boundary Responsibilities

| Engine        | Responsibilities                                                            |
| ------------- | --------------------------------------------------------------------------- |
| `Identity`    | Identity, authentication, passkeys, tokens, and audit-sensitive login state |
| `Zenith`      | Acme shared shell, shared preferences, and coordination flows               |
| `Foundation`  | `base.*` business and admin flows                                           |
| `Distributor` | `post.*` content and API delivery flows                                     |

## 4. Data Design

### 4.1 Database ownership

| Database group                                                                    | Owner                 |
| --------------------------------------------------------------------------------- | --------------------- |
| `principal`, `operator`, `token`, `preference`, `guest`, `activity`, `occurrence` | Activity              |
| `journal`, `notification`, `avatar`                                               | Journal               |
| `publication`                                                                     | Distributor           |
| `chronicle`, `message`, `search`, `billing`, `commerce`                           | Foundation            |
| `queue`, `cache`, `storage`, `cable`                                              | Shared infrastructure |

### 4.2 Model policy

- Keep a single model definition when several engines use the same table family.
- Use base records to express database ownership.
- Move a model into an engine only when the boundary truly requires it.

## 5. Key Flows

- Sign-in and token flow happen in `Identity`.
- Shared entry and shared preference navigation happen in `Zenith`.
- Business and admin flows happen in `Foundation`.
- Delivery and read-oriented API flows happen in `Distributor`.

## 6. Verification

- Route tests confirm host isolation.
- Model tests confirm database ownership.
- Integration tests confirm cross-boundary navigation.
- Security tests confirm auth, redirect, and audit rules.
