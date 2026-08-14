import { Link, router } from "@inertiajs/react";
import { useState } from "react";

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

function ActionButton({
  url,
  label,
  confirm,
  method,
}: {
  url: string;
  label: string;
  confirm?: string;
  method: "post" | "delete";
}) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (confirm && !window.confirm(confirm)) {
      return;
    }
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

  return (
    <form onSubmit={submit}>
      <button
        type="submit"
        disabled={processing}
      >
        {label}
      </button>
    </form>
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
    <section>
      <h1>{title}</h1>

      {terminated ? (
        <p>{unavailableMessage}</p>
      ) : (
        <>
          {deadlineMessage ? <p>{deadlineMessage}</p> : null}

          {recovery.available_message ? <p>{recovery.available_message}</p> : null}
          {recovery.url && recovery.submit_label ? (
            <ActionButton
              url={recovery.url}
              label={recovery.submit_label}
              confirm={recovery.confirm}
              method="post"
            />
          ) : null}
          {recovery.pending_message ? <p>{recovery.pending_message}</p> : null}
          {recovery.unavailable_message ? <p>{recovery.unavailable_message}</p> : null}

          {termination?.url && termination.submit_label ? (
            <ActionButton
              url={termination.url}
              label={termination.submit_label}
              confirm={termination.confirm}
              method="delete"
            />
          ) : null}
          {termination?.pending_message ? <p>{termination.pending_message}</p> : null}

          <p>
            <Link href={privacyErasureLink.href}>{privacyErasureLink.label}</Link>
          </p>
        </>
      )}

      <ActionButton
        url={signOut.url}
        label={signOut.label}
        method="delete"
      />
    </section>
  );
}
