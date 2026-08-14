import { router } from "@inertiajs/react";
import { useState } from "react";

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

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!window.confirm(action.confirm)) {
      return;
    }
    router.delete(action.url, {
      data,
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <form onSubmit={submit}>
      <button
        type="submit"
        disabled={processing}
      >
        {action.label}
      </button>
    </form>
  );
}
