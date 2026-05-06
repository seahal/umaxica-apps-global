# High-Level Design

## 1. Purpose

This document describes the target architecture for the Rails platform. The system is organized
around four engines:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

Engine names are responsibility boundaries. Host labels are separate entry labels.

## 2. Architecture Overview

### 2.1 Responsibilities

| Engine        | Responsibility                                                              |
| ------------- | --------------------------------------------------------------------------- |
| `Identity`    | Identity, authentication, passkeys, tokens, and audit-sensitive login state |
| `Zenith`      | Acme shared shell, shared coordination, and shared preferences              |
| `Foundation`  | `base.*` business and admin flows                                           |
| `Distributor` | `post.*` content and API delivery flows                                     |

### 2.2 Routing

- All engines use `isolate_namespace`.
- Cross-boundary links use native Rails routing proxies.
- Host app routes use `main_app`.

### 2.3 Data Ownership

| Database group                                                                    | Owner                 |
| --------------------------------------------------------------------------------- | --------------------- |
| `principal`, `operator`, `token`, `preference`, `guest`, `activity`, `occurrence` | Activity              |
| `journal`, `notification`, `avatar`                                               | Journal               |
| `publication`                                                                     | Distributor           |
| `chronicle`, `message`, `search`, `billing`, `commerce`                           | Foundation            |
| `queue`, `cache`, `storage`, `cable`                                              | Shared infrastructure |

## 3. Components

- Controllers and views are organized by engine and host label.
- Models stay centralized in `app/models`.
- Shared concerns and services stay in the host app.
- Database ownership is expressed by base records and `connects_to`.

## 4. Deployment

| Mode          | Mounted engines                           |
| ------------- | ----------------------------------------- |
| `identity`    | Identity                                  |
| `zenith`      | Zenith                                    |
| `foundation`  | Foundation                                |
| `distributor` | Distributor                               |
| `development` | Identity, Zenith, Foundation, Distributor |

## 5. Quality Goals

- Keep security boundaries explicit.
- Keep routing readable.
- Keep data ownership stable.
- Keep the model layer shared unless a later boundary requires a split.
