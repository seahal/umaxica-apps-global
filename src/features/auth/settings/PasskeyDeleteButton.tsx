// Removes one registered passkey.
//
// It keeps the shape the ERB form had: a DELETE to the same route, a confirmation the actor has to
// accept, and an invisible Turnstile token travelling with the request. The token is only ever
// solved in the browser; the server decides what it is worth.
import { router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

export type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type PasskeyDeleteButtonProps = {
  action: string;
  label: string;
  confirm_message: string;
  turnstile: TurnstileConfiguration;
};

export default function PasskeyDeleteButton({
  action,
  label,
  confirm_message: confirmMessage,
  turnstile,
}: PasskeyDeleteButtonProps) {
  const [token, setToken] = useState("");
  const { confirm, dialog } = useConfirm();

  const destroy = () => {
    confirm({ message: confirmMessage, confirmLabel: label }, () => {
      router.delete(action, { data: { "cf-turnstile-response": token } });
    });
  };

  return (
    <div className="flex items-center gap-2">
      <TurnstileWidget
        site_key={turnstile.site_key}
        mode={turnstile.mode}
        action={turnstile.action}
        cdata={turnstile.cdata}
        onToken={setToken}
      />
      <Button
        variant="danger"
        size="sm"
        onPress={destroy}
      >
        {label}
      </Button>
      {dialog}
    </div>
  );
}
