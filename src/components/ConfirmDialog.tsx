// The one confirmation a destructive action goes through.
//
// The ERB screens gated destructive actions with `data-turbo-confirm`, whose copy the server wrote.
// This keeps that arrangement: the message and the labels are props that arrive already translated,
// and the dialog only decides when the action fires. Nothing here authors visitor-facing copy.
import { useCallback, useEffect, useId, useRef, useState } from "react";

/** A confirmation the actor has to accept before a destructive action fires. */
export type ConfirmRequest = {
  /** The server's confirmation copy, the string `data-turbo-confirm` used to carry. */
  message: string;
  /** The server's label for the action being confirmed. */
  confirmLabel: string;
  /** The server's label for declining, on the screens whose props carry one. */
  cancelLabel?: string;
};

type PendingConfirmation = ConfirmRequest & { accept: () => void };

// Declining is always reachable by Escape and by this control. A screen whose props carry no label
// for it gets the dismissal glyph rather than an English string invented here.
const DISMISS_GLYPH = "✕";

export function ConfirmDialog({
  pending,
  onDismiss,
}: {
  pending: PendingConfirmation | null;
  onDismiss: () => void;
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const dismissRef = useRef<HTMLButtonElement>(null);
  const messageId = useId();

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) {
      return;
    }

    if (pending) {
      if (!dialog.open) {
        // `showModal`/`close` are what make the dialog modal, focus-trapped and Escape-closing.
        // jsdom implements neither, so the `open` attribute keeps the same markup reachable under
        // test; a browser always takes the modal path.
        if (typeof dialog.showModal === "function") {
          dialog.showModal();
        } else {
          dialog.open = true;
        }
      }
      // Declining is the safe answer, so it holds the focus the dialog opens with.
      dismissRef.current?.focus();
    } else if (dialog.open) {
      if (typeof dialog.close === "function") {
        dialog.close();
      } else {
        dialog.open = false;
      }
    }
  }, [pending]);

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby={messageId}
      onClose={onDismiss}
      onKeyDown={(event) => {
        if (event.key === "Escape") {
          onDismiss();
        }
      }}
    >
      {pending ? (
        <div>
          <p id={messageId}>{pending.message}</p>
          <button
            type="button"
            ref={dismissRef}
            onClick={onDismiss}
          >
            {pending.cancelLabel ?? DISMISS_GLYPH}
          </button>
          <button
            type="button"
            onClick={() => {
              const { accept } = pending;
              onDismiss();
              accept();
            }}
          >
            {pending.confirmLabel}
          </button>
        </div>
      ) : null}
    </dialog>
  );
}

/**
 * Gates a destructive action behind {@link ConfirmDialog}.
 *
 * The caller renders `dialog` once and calls `confirm(request, action)` where it used to call
 * `window.confirm`; `action` runs only after the actor accepts, and runs with the same verb and
 * payload it had before.
 */
export function useConfirm() {
  const [pending, setPending] = useState<PendingConfirmation | null>(null);

  const confirm = useCallback((request: ConfirmRequest, accept: () => void) => {
    setPending({ ...request, accept });
  }, []);

  const dismiss = useCallback(() => setPending(null), []);

  const dialog = (
    <ConfirmDialog
      pending={pending}
      onDismiss={dismiss}
    />
  );

  return { confirm, dialog };
}

export default ConfirmDialog;
