# Accessibility Checklist (WCAG 2.1 AA)

## Contents

- Perceivable
- Operable
- Understandable
- Robust
- Testing tools
- Manual checks no tool covers

## Perceivable

- [ ] Every meaningful image has alt text; decorative images have `alt=""`
- [ ] Text contrast is at least 4.5:1 for body text and 3:1 for large text (≥ 18.66px bold or 24px)
- [ ] Non-text UI — icon buttons, form borders, focus rings — meets 3:1 against its background
- [ ] Colour is never the only carrier of meaning; pair it with text, shape, or an icon
- [ ] Content reflows without horizontal scrolling at 320px width and at 200% zoom
- [ ] Video has captions; audio has a transcript

## Operable

- [ ] Every interactive element is reachable and operable by keyboard alone
- [ ] Focus order follows the visual reading order
- [ ] The focus indicator is always visible and never removed without a stronger replacement
- [ ] No keyboard trap: focus can always move out of a component
- [ ] Dialogs move focus in on open, trap it while open, and restore it on close
- [ ] Skip-to-content link precedes repeated navigation
- [ ] Motion respects `prefers-reduced-motion`
- [ ] Nothing auto-plays, auto-scrolls, or auto-advances without a pause control

## Understandable

- [ ] The page declares its language with `<html lang>`
- [ ] Every form control has a programmatically associated label
- [ ] Errors are announced, identify the field, and describe how to fix it
- [ ] Navigation and component naming stay consistent across pages
- [ ] Focus alone never triggers a context change such as navigation or submission

## Robust

- [ ] Semantic elements are used before ARIA — `<button>` before `role="button"`
- [ ] ARIA roles, states, and properties are valid for the element they sit on
- [ ] Status changes are announced through a live region (`role="status"` or `aria-live`)
- [ ] Empty and error states render meaningful content, not a blank region
- [ ] The accessibility tree exposes name, role, and value for every control

## Testing tools

```bash
# Automated audit of a running page
npx lighthouse <url> --only-categories=accessibility

# Component-level checks in the test suite
npm install --save-dev @axe-core/react   # development-time reporting
npm install --save-dev jest-axe          # assertions in unit tests
```

Automated tools catch roughly a third of WCAG failures. Passing them is necessary, not sufficient.

## Manual checks no tool covers

1. Unplug the mouse and complete the primary flow with the keyboard alone.
2. Tab through the page and confirm the focus indicator is visible at every stop.
3. Zoom to 200% and confirm nothing is clipped or requires horizontal scrolling.
4. Read the page with a screen reader and confirm each control announces a name that matches its
   visible label.
5. Trigger a validation error and confirm it is announced, not only shown in red.
