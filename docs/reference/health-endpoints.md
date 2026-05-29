# Health Endpoints

Health endpoints return the shared runtime health contract from `Health`.

JSON responses use:

```json
{
  "status": "OK",
  "service": "sign",
  "version": "114fe4bd-6ee1-4f37-bf61-8e3ce208684a",
  "time": "2026-05-29T00:17:52.131Z"
}
```

Plain text responses use the same fields:

```text
status=OK service=sign version=114fe4bd-6ee1-4f37-bf61-8e3ce208684a time=2026-05-29T00:17:52.131Z
```

`service` is the top-level service namespace, such as `sign`, `acme`, or `core`. `version` comes
from `Rails.app.revision`. `time` is UTC ISO 8601 with milliseconds and a trailing `Z`.
