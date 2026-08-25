import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button, { type ButtonVariant } from "@/components/ui/Button";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/withdrawals/edit.html.erb`, the recovery and early
// termination screen of the withdrawal ceremony.

export type WithdrawalRecoverySection = {
  available_message?: string;
  pending_message?: string;
  unavailable_message?: string;
  url?: string;
  submit_label?: string;
  confirm?: string;
};

export type WithdrawalEditProps = {
  title: string;
  terminated: boolean;
  unavailable_message: string;
  deadline_message: string | null;
  recovery: WithdrawalRecoverySection;
  termination: WithdrawalRecoverySection | null;
  privacy_erasure_link: PageLink;
  sign_out: { label: string; url: string };
};

const LINK = "text-sm text-fg-muted underline-offset-4 hover:text-fg hover:underline";

function ActionButton({
  url,
  label,
  confirm,
  method,
  variant,
}: {
  url: string;
  label: string;
  // `| undefined` is explicit because the caller forwards an optional server prop straight
  // through; an absent value means the action was never gated by a confirmation.
  confirm?: string | undefined;
  method: "post" | "delete";
  variant: ButtonVariant;
}) {
  const [processing, setProcessing] = useState(false);
  const { confirm: requestConfirmation, dialog } = useConfirm();

  const send = () => {
    const options = {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    };
    if (method === "delete") {
      router.delete(url, options);
    } else {
      router.post(url, {}, options);
    }
  };

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    // An action the server sent no confirmation copy for was never gated by one.
    if (confirm) {
      requestConfirmation({ message: confirm, confirmLabel: label }, send);
      return;
    }
    send();
  };

  return (
    <>
      <form onSubmit={submit}>
        <Button
          type="submit"
          variant={variant}
          isDisabled={processing}
        >
          {label}
        </Button>
      </form>
      {dialog}
    </>
  );
}

export default function WithdrawalEdit({
  title,
  terminated,
  unavailable_message: unavailableMessage,
  deadline_message: deadlineMessage,
  recovery,
  termination,
  privacy_erasure_link: privacyErasureLink,
  sign_out: signOut,
}: WithdrawalEditProps) {
  return (
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>

      {terminated ? (
        <p className="text-sm text-fg-muted">{unavailableMessage}</p>
      ) : (
        <div className="flex flex-col gap-4">
          {deadlineMessage ? <p className="text-sm text-fg-muted">{deadlineMessage}</p> : null}

          <section className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4">
            {recovery.available_message ? (
              <p className="text-sm text-fg">{recovery.available_message}</p>
            ) : null}
            {recovery.url && recovery.submit_label ? (
              <div>
                <ActionButton
                  url={recovery.url}
                  label={recovery.submit_label}
                  confirm={recovery.confirm}
                  method="post"
                  variant="primary"
                />
              </div>
            ) : null}
            {recovery.pending_message ? (
              <p className="text-sm text-fg-muted">{recovery.pending_message}</p>
            ) : null}
            {recovery.unavailable_message ? (
              <p className="text-sm text-fg-muted">{recovery.unavailable_message}</p>
            ) : null}
          </section>

          {termination ? (
            <section className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4">
              {termination.url && termination.submit_label ? (
                <div>
                  <ActionButton
                    url={termination.url}
                    label={termination.submit_label}
                    confirm={termination.confirm}
                    method="delete"
                    variant="danger"
                  />
                </div>
              ) : null}
              {termination.pending_message ? (
                <p className="text-sm text-fg-muted">{termination.pending_message}</p>
              ) : null}
            </section>
          ) : null}

          <p>
            <Link
              href={privacyErasureLink.href}
              className={LINK}
            >
              {privacyErasureLink.label}
            </Link>
          </p>
        </div>
      )}

      <div>
        <ActionButton
          url={signOut.url}
          label={signOut.label}
          method="delete"
          variant="secondary"
        />
      </div>
    </section>
  );
}
