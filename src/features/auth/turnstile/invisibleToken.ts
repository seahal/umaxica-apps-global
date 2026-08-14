// Solves a Turnstile challenge invisibly and hands back the token, for ceremonies that post JSON
// instead of submitting a form.
//
// This is the `ensureTurnstileToken` / `requestTurnstileToken` pair of
// `src/controllers/passkey_authentication_controller.js`, unchanged in behaviour: an invisible
// widget is rendered into a detached container, its callback resolves with the token, and any
// error or expiry rejects. A rejection means the challenge could not be presented, which the caller
// must surface - it is never treated as a passed challenge. The server still verifies the token.
import { waitForTurnstileApi, type TurnstileOptions } from "@/lib/turnstile";

/** `size` is not part of the shared options type because only the invisible flow sets it. */
type InvisibleOptions = Partial<TurnstileOptions> & {
  sitekey: string;
  size: "invisible";
  callback: (token: string) => void;
  "error-callback": () => void;
  "expired-callback": () => void;
};

export async function solveInvisibleTurnstile(
  siteKey: string,
  errorMessage: string,
  host: HTMLElement | null,
): Promise<string> {
  if (!siteKey) {
    throw new Error(errorMessage);
  }

  const api = await waitForTurnstileApi(errorMessage);

  return new Promise<string>((resolve, reject) => {
    try {
      const container = document.createElement("div");
      container.style.display = "none";
      (host ?? document.body).append(container);

      const options: InvisibleOptions = {
        sitekey: siteKey,
        size: "invisible",
        callback: (token: string) => resolve(token),
        "error-callback": () => reject(new Error(errorMessage)),
        "expired-callback": () => reject(new Error(errorMessage)),
      };

      api.render(container, options as unknown as TurnstileOptions);
    } catch (error) {
      // oxlint-disable-next-line no-console
      console.error("Turnstile token request failed:", error);
      reject(new Error(errorMessage));
    }
  });
}
