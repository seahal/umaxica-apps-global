// The invisible Turnstile token the fetch-driven passkey ceremonies solve before they call the
// server. It is the React port of `ensureTurnstileToken`/`requestTurnstileToken` from the Stimulus
// passkey controllers: same `size: "invisible"` widget, same site key, same rejection on error or
// expiry. The server still verifies the token, so nothing about the guard moved to the client.
//
// `src/features/turnstile/TurnstileWidget.tsx` covers the two widget shapes that sit next to a
// form; this covers the third shape, the one that solves a token on demand inside a JSON ceremony.
import { waitForTurnstileApi, type TurnstileOptions } from "@/lib/turnstile";

type InvisibleTurnstileOptions = TurnstileOptions & { size: "invisible" };

export async function solveInvisibleTurnstile(
  siteKey: string,
  errorMessage: string,
  host: HTMLElement | null,
): Promise<string> {
  if (!siteKey) {
    throw new Error(errorMessage);
  }

  const turnstile = await waitForTurnstileApi(errorMessage);

  return new Promise<string>((resolve, reject) => {
    const container = document.createElement("div");
    container.style.display = "none";
    (host ?? document.body).append(container);

    const options: InvisibleTurnstileOptions = {
      sitekey: siteKey,
      size: "invisible",
      callback: (token: string) => resolve(token),
      "error-callback": () => {
        reject(new Error(errorMessage));
        return true;
      },
      "expired-callback": () => reject(new Error(errorMessage)),
      "timeout-callback": () => reject(new Error(errorMessage)),
      "unsupported-callback": () => reject(new Error(errorMessage)),
    };

    try {
      turnstile.render(container, options);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Turnstile token request failed:", error);
      reject(new Error(errorMessage));
    }
  });
}
