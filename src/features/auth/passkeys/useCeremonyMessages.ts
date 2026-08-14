import { useCallback, useState } from "react";

export type CeremonyMessages = {
  error: string;
  status: string;
  showError: (message: string) => void;
  showStatus: (message: string) => void;
  clearMessages: () => void;
};

/**
 * The error/status pair every passkey ceremony page showed through the Stimulus `error` and
 * `status` targets. Setting an error clears the status, exactly as `showError` did.
 */
export function useCeremonyMessages(): CeremonyMessages {
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");

  const showError = useCallback((message: string) => {
    setError(message);
    setStatus("");
  }, []);

  const showStatus = useCallback((message: string) => {
    setStatus(message);
  }, []);

  const clearMessages = useCallback(() => {
    setError("");
    setStatus("");
  }, []);

  return { error, status, showError, showStatus, clearMessages };
}
