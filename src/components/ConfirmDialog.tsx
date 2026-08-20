// The one confirmation a destructive action goes through.
//
// The ERB screens gated destructive actions with `data-turbo-confirm`, whose copy the server wrote.
// This keeps that arrangement: the message and the labels are props that arrive already translated,
// and the dialog only decides when the action fires. Nothing here authors visitor-facing copy.
//
// The modal behaviour — focus trap, focus restore, Escape, inert background — belongs to React Aria
// via `@/components/ui/Dialog`. This file previously drove a native `<dialog>` and fell back to
// setting its `open` attribute wherever `showModal()` was missing, which meant the tests exercised
// an unguarded path that never shipped.
import { useCallback, useState } from "react";

import Button from "@/components/ui/Button";
import Dialog from "@/components/ui/Dialog";

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

function ConfirmDialog({
  pending,
  onDismiss,
}: {
  pending: PendingConfirmation | null;
  onDismiss: () => void;
}) {
  return (
    <Dialog
      // The message names the dialog. There is no separate server-supplied title, and inventing one
      // here would be authoring copy.
      title={pending?.message ?? ""}
      isOpen={pending !== null}
      onOpenChange={(isOpen) => {
        if (!isOpen) {
          onDismiss();
        }
      }}
    >
      {pending ? (
        <div className="flex flex-wrap justify-end gap-2">
          {/*
            Declining is the safe answer, so it holds the focus the dialog opens with. Without
            `autoFocus` React Aria focuses the dialog container itself, which is a safe default but
            costs the actor a keystroke to reach the answer they are most likely to want.
          */}
          <Button
            autoFocus
            variant="secondary"
            onPress={onDismiss}
          >
            {pending.cancelLabel ?? DISMISS_GLYPH}
          </Button>

          <Button
            variant="danger"
            onPress={() => {
              const { accept } = pending;
              onDismiss();
              accept();
            }}
          >
            {pending.confirmLabel}
          </Button>
        </div>
      ) : null}
    </Dialog>
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
