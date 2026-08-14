// Type declarations for the framework-agnostic browser helpers that the Stimulus controllers and
// the React auth pages both use. `webauthn_utils` stays plain JavaScript because the Stimulus
// controllers of the not-yet-migrated surfaces still import it; this declaration lets the
// TypeScript auth pages import the same module without duplicating it.

declare module "@/controllers/webauthn_utils" {
  export function toArrayBuffer(input: unknown, label?: string): ArrayBuffer;
  export function normalizePublicKeyOptions(
    options: unknown,
  ): PublicKeyCredentialCreationOptions & PublicKeyCredentialRequestOptions;
}

// The Cloudflare Turnstile script attaches its API to `window` once it loads. `src/lib/turnstile.ts`
// owns the API shape; this only records that the global may be present.
interface Window {
  turnstile?: import("@/lib/turnstile").TurnstileApi;
}
