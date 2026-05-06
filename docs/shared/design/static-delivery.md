# Static File Delivery

## Overview

Architecture for delivering static files and error pages via Amazon CloudFront with S3 origins.
Compiled assets are delivered from Cloudflare R2.

## S3 Bucket Strategy

Each engine/hostlabel/audience combination has two dedicated S3 buckets. Bucket names follow the
canonical ENV naming pattern (`ENGINE_HOSTLABEL_AUDIENCE_*`):

| Suffix    | Purpose                         | Example contents       |
| --------- | ------------------------------- | ---------------------- |
| `_PUBLIC` | Static files served directly    | `favicon.ico`          |
| `_ERROR`  | Error pages for failed requests | `404.html`, `500.html` |

### Bucket Examples

| Bucket name                  | Contents                     |
| ---------------------------- | ---------------------------- |
| `ZENITH_ACME_COM_PUBLIC`     | `favicon.ico`, static assets |
| `ZENITH_ACME_COM_ERROR`      | `404.html`, `500.html`       |
| `IDENTITY_SIGN_APP_PUBLIC`   | `favicon.ico`, static assets |
| `IDENTITY_SIGN_APP_ERROR`    | `404.html`, `500.html`       |
| `FOUNDATION_BASE_ORG_PUBLIC` | `favicon.ico`, static assets |
| `FOUNDATION_BASE_ORG_ERROR`  | `404.html`, `500.html`       |

## Request Flow

### Normal Static Request

```
User -> CloudFront -> _PUBLIC bucket (S3)
                      e.g. ZENITH_ACME_COM_PUBLIC/favicon.ico
```

### When an Error Occurs

1. **User request**

   ```
   User -> https://umaxica.com/unknown-page
   ```

2. **CloudFront forwards to Rails origin**

   ```
   CloudFront -> Rails application
   ```

3. **Rails responds with error status**

   ```
   Rails -> returns 404
   ```

4. **CloudFront custom error response**

   ```
   CloudFront -> fetches from _ERROR bucket
                 e.g. ZENITH_ACME_COM_ERROR/404.html
   ```

5. **Deliver to the user**

   ```
   CloudFront -> serves 404.html (no URL change)
   ```

## CloudFront Configuration

- Each audience tier has a CloudFront distribution (or behavior) that routes to the correct S3
  bucket pair.
- Custom error responses map HTTP status codes (404, 500) to the `_ERROR` bucket.
- The browser address bar remains unchanged when an error page is served.

### Benefits

- **Stable URL**: The browser address bar remains unchanged.
- **Resilience**: Error pages render even if the Rails application is down.
- **Performance**: Static files are delivered from edge locations.
- **Isolation**: Each engine/audience combination has its own bucket pair.

## Compiled Assets

- Asset build runs on the Amazon CD pipeline.
- Compiled output (CSS, JS) is uploaded to Cloudflare R2 for delivery.
- This approach was previously validated in the staging environment.

## Asset Pipeline Strategy

TODO: Not yet decided.

## Current Status

- Domain-specific error pages exist on the Rails side (`public/404.html`, `public/500.html`)
- S3 bucket provisioning and CloudFront configuration remain TODO
- Per-audience error pages (`/com/`, `/app/`, `/org/`, `/dev/`) remain TODO
