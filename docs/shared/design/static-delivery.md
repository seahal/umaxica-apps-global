# Static File Delivery

## Overview

Architecture for delivering static files and error pages via CDN-backed object storage. Compiled
assets may be delivered from Cloudflare R2 or another configured asset origin.

## Bucket Strategy

Static and error-page buckets should be named by deployable surface or host family, not by retired
Rails Engine names.

| Suffix    | Purpose                         | Example contents       |
| --------- | ------------------------------- | ---------------------- |
| `_PUBLIC` | Static files served directly    | `favicon.ico`          |
| `_ERROR`  | Error pages for failed requests | `404.html`, `500.html` |

### Bucket Examples

| Bucket name  | Contents                     |
| ------------ | ---------------------------- |
| `APP_PUBLIC` | `favicon.ico`, static assets |
| `APP_ERROR`  | `404.html`, `500.html`       |
| `ORG_PUBLIC` | `favicon.ico`, static assets |
| `COM_ERROR`  | `404.html`, `500.html`       |

## Request Flow

### Normal Static Request

```
User -> CDN -> _PUBLIC bucket
```

### When an Error Occurs

1. User requests an application URL.
2. CDN forwards to the Rails origin.
3. Rails responds with an error status.
4. CDN custom error response fetches from the `_ERROR` bucket.
5. CDN serves the error page without changing the browser URL.

## CloudFront Configuration

- Each surface or host family may have a CloudFront distribution or behavior that routes to the
  correct bucket pair.
- Custom error responses map HTTP status codes such as 404 and 500 to the `_ERROR` bucket.
- The browser address bar remains unchanged when an error page is served.

## Current Status

- Domain-specific error pages exist on the Rails side (`public/404.html`, `public/500.html`).
- CDN bucket provisioning and custom error response configuration remain TODO.
- Per-surface error pages remain TODO.
