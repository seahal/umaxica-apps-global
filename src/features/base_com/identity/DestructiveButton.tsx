import { router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import type { ConfirmedAction } from "@/features/base_com/identity/types";

// The ERB used `button_to ... data: { turbo_confirm: }`, which is a real DELETE behind a
// confirmation. This keeps both halves: the verb the route expects, and the confirmation.

export default function DestructiveButton({
  action,
  data,
}: {
  action: ConfirmedAction;
  data?: Record<string, string>;
}) {
  const [processing, setProcessing] = useState(false);
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    confirm({ message: action.confirm, confirmLabel: action.label }, () => {
      router.delete(action.url, {
        // Omitted rather than sent as undefined: the adapter declares `data` optional, and a
        // DELETE with no payload is a different request from one with an empty one.
        ...(data === undefined ? {} : { data }),
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      });
    });
  };

  return (
    <>
      <form onSubmit={submit}>
        <button
          type="submit"
          disabled={processing}
        >
          {action.label}
        </button>
      </form>
      {dialog}
    </>
  );
}
