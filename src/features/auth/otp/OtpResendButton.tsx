// React port of `src/controllers/otp_resend_controller.js`.
//
// The endpoint, the request body and the three outcomes are unchanged: 200 with `resendable` clears
// the code field and reports that a new code was sent, 429 starts the cooldown the server dictated
// via `retry_after`, and anything else reports a failure. The resend state is an opaque server
// token; the browser only echoes it back.
import { useEffect, useRef, useState } from "react";

export type OtpResendMessages = {
  button_label: string;
  sent_message: string;
  too_soon_message: string;
  failed_message: string;
};

export type OtpResendButtonProps = {
  endpoint: string;
  state: string;
  messages: OtpResendMessages;
  /** Called after a successful resend so the form can clear the code the actor already typed. */
  onResent?: () => void;
};

function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content ?? "";
}

export default function OtpResendButton({
  endpoint,
  state,
  messages,
  onResent,
}: OtpResendButtonProps) {
  const [status, setStatus] = useState("");
  const [remaining, setRemaining] = useState(0);
  const remainingRef = useRef(0);

  remainingRef.current = remaining;

  useEffect(() => {
    if (remaining <= 0) {
      return;
    }

    const timer = window.setInterval(() => {
      setRemaining((seconds) => Math.max(seconds - 1, 0));
    }, 1000);

    return () => window.clearInterval(timer);
  }, [remaining]);

  const resend = async () => {
    if (remainingRef.current > 0) {
      return;
    }

    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({ state: state }),
      });

      const payload = (await response.json()) as { resendable?: boolean; retry_after?: number };

      if (response.status === 200 && payload.resendable === true) {
        onResent?.();
        setStatus(messages.sent_message);
        setRemaining(0);
        return;
      }

      if (response.status === 429) {
        setStatus(messages.too_soon_message);
        setRemaining(Math.max(Math.ceil(Number(payload.retry_after || 0)), 0));
        return;
      }

      setStatus(messages.failed_message);
    } catch {
      setStatus(messages.failed_message);
    }
  };

  return (
    <div>
      <button
        type="button"
        disabled={remaining > 0}
        onClick={() => void resend()}
      >
        {remaining > 0 ? `${messages.too_soon_message} (${remaining}s)` : messages.button_label}
      </button>
      <p>{status}</p>
    </div>
  );
}
