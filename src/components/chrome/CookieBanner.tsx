// React port of the `cookie-banner` Stimulus controller.
//
// The consent decision itself stays on the server: this component only reports a choice to
// /web/v0/cookie and reflects what the server answers. It never writes the consent cookie itself,
// because the verified preference JWT is minted server-side.
import { useEffect, useState } from "react";

import { readBoolean } from "@/lib/payload";
import { csrfToken, preferenceQueryParameters } from "@/lib/request";
import type { ChromeCookieControls } from "@/types/inertia";

function cookieEndpointUrl(): string {
  const endpoint = new URL("/web/v0/cookie", window.location.origin);
  for (const [key, value] of preferenceQueryParameters()) {
    endpoint.searchParams.set(key, value);
  }
  return endpoint.toString();
}

export default function CookieBanner({ controls }: { controls: ChromeCookieControls }) {
  const [visible, setVisible] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let active = true;

    const readConsent = async () => {
      try {
        const response = await fetch(cookieEndpointUrl());
        if (!response.ok) {
          return;
        }
        const state: unknown = await response.json();
        if (active && readBoolean(state, "consented") === true) {
          setVisible(false);
        }
      } catch {
        // Keep the banner visible when the verified preference JWT cannot be read.
      }
    };

    void readConsent();

    return () => {
      active = false;
    };
  }, []);

  if (!visible) {
    return null;
  }

  const submitConsent = async (consented: boolean) => {
    setSubmitting(true);
    try {
      const response = await fetch(cookieEndpointUrl(), {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({
          // Recording a decision is itself consent to store it, so `consented` is true for both
          // answers; the category flags carry the actual choice.
          cookie: {
            consented: true,
            functional: consented,
            performant: consented,
            targetable: consented,
          },
        }),
      });

      if (response.ok) {
        setVisible(false);
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      id="cookie-banner"
      role="dialog"
      aria-live="polite"
      aria-labelledby="cookie-title"
      aria-describedby="cookie-desc"
      className="fixed bottom-0 inset-x-0 z-50 bg-white border-t border-gray-300 shadow"
    >
      <div className="max-w-4xl mx-auto p-4 space-y-3 relative">
        <button
          type="button"
          onClick={() => setVisible(false)}
          aria-label={controls.close_button}
          className="absolute top-2 right-2 p-2 rounded-full text-gray-400 hover:bg-gray-100 hover:text-gray-700 transition focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="w-4 h-4"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <line
              x1="18"
              y1="6"
              x2="6"
              y2="18"
            />
            <line
              x1="6"
              y1="6"
              x2="18"
              y2="18"
            />
          </svg>
        </button>

        <h2
          id="cookie-title"
          className="text-sm font-semibold pr-8"
        >
          {controls.title}
        </h2>

        <p
          id="cookie-desc"
          className="text-sm text-gray-700"
        >
          {controls.description_html}
        </p>

        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submitConsent(false)}
            className="px-3 py-1.5 text-sm rounded border border-gray-300 hover:bg-gray-50"
          >
            {controls.reject_all}
          </button>

          <button
            type="button"
            onClick={() => window.location.assign(controls.settings_url)}
            className="px-3 py-1.5 text-sm rounded bg-gray-200 hover:bg-gray-300"
          >
            {controls.open_settings}
          </button>

          <button
            type="button"
            disabled={submitting}
            onClick={() => void submitConsent(true)}
            className="px-3 py-1.5 text-sm rounded bg-blue-600 text-white hover:bg-blue-700"
          >
            {controls.accept_all}
          </button>
        </div>
      </div>
    </div>
  );
}
