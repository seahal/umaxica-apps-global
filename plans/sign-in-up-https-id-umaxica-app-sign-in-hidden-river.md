# Fix: Vite entrypoint path double-prefixed in all surface layouts

## Context

After splitting the monolithic `"application"` entrypoint into per-surface files (`sign/app`,
`acme/app`, etc.), all six layout files were updated to use the new paths — but each path was
incorrectly prefixed with `entrypoints/`. vite-ruby already resolves names relative to
`src/entrypoints/` (the `sourceCodeDir` + default `entrypointsDir`), so `"entrypoints/sign/app"`
tries to load `src/entrypoints/entrypoints/sign/app.ts`, which does not exist. The asset returns
404, Inertia.js fails to boot, and the sign-in page stalls.

## Fix

In each of the six layout files, remove the `entrypoints/` prefix from the `vite_typescript_tag`
argument:

| File                                              | Before                   | After        |
| ------------------------------------------------- | ------------------------ | ------------ |
| `app/views/layouts/sign/app/application.html.erb` | `"entrypoints/sign/app"` | `"sign/app"` |
| `app/views/layouts/sign/com/application.html.erb` | `"entrypoints/sign/com"` | `"sign/com"` |
| `app/views/layouts/sign/org/application.html.erb` | `"entrypoints/sign/org"` | `"sign/org"` |
| `app/views/layouts/acme/app/application.html.erb` | `"entrypoints/acme/app"` | `"acme/app"` |
| `app/views/layouts/acme/com/application.html.erb` | `"entrypoints/acme/com"` | `"acme/com"` |
| `app/views/layouts/acme/org/application.html.erb` | `"entrypoints/acme/org"` | `"acme/org"` |

The actual entrypoint files (`src/entrypoints/sign/app.ts` etc.) are already in place and correct —
only the path strings in the layouts need fixing.

## Verification

Run `bin/rails test test/integration/layouts_stylesheet_test.rb` (already modified in this branch)
then open the sign-in URL in a browser and confirm the JS boots without 404 errors in the network
tab.
