# GH-581: Resolve URL Issues Across All Domain Application Controllers

GitHub: #581

## Summary

15 application controllers across all domain surfaces contain the same FIXME:

> `Resolve the URL issues before deploying.`

This is a **deploy blocker** that must be resolved before production release.

## Affected Files

- `app/controllers/acme/app/application_controller.rb:37`
- `app/controllers/acme/com/application_controller.rb:37`
- `app/controllers/acme/org/application_controller.rb:35`
- `app/controllers/core/app/application_controller.rb:19`
- `app/controllers/core/com/application_controller.rb:19`
- `app/controllers/core/org/application_controller.rb:19`
- `app/controllers/docs/app/application_controller.rb:27`
- `app/controllers/docs/com/application_controller.rb:26`
- `app/controllers/docs/org/application_controller.rb:25`
- `app/controllers/help/app/application_controller.rb:35`
- `app/controllers/help/com/application_controller.rb:36`
- `app/controllers/help/org/application_controller.rb:37`
- `app/controllers/news/app/application_controller.rb:38`
- `app/controllers/news/com/application_controller.rb:36`
- `app/controllers/news/org/application_controller.rb:36`

## Action

Investigate the URL configuration issue pattern, fix all 15 controllers, then remove the FIXME
annotations. Add tests to verify URL generation is correct across surfaces.

## Implementation Status (2026-04-07)

**Status: PARTIALLY DONE**

- 9 of 15 controllers still contain the FIXME (acme/_, core/_, docs/\*).
- 6 controllers (help/_, news/_) no longer exist — those surfaces were removed or restructured.
- Remaining 9 controllers still need the URL configuration resolved.

## Improvement Points (2026-04-07 Review)

- The task is still open in the repository. Multiple controllers still carry the FIXME and hardcoded
  localhost trusted-origin values.
- Replace the controller-by-controller list with one shared configuration strategy plus regression
  tests, otherwise this issue will keep drifting as more surfaces are added.
