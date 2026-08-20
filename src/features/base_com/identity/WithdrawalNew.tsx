import { Link, router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import ErrorList from "@/features/base_com/identity/ErrorList";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/withdrawals/new.html.erb`. The deactivation step is absent
// from the props until the schedule has been acknowledged, so the gate stays a server decision.

export type WithdrawalAckForm = {
  title: string;
  errors: string[];
  url: string;
  method: "get" | "patch";
  field: string;
  ack_label: string;
  checked?: boolean;
  submit_label: string;
  confirm?: string;
};

export type WithdrawalNewProps = {
  title: string;
  already_deactivated: boolean;
  already_deactivated_message: string;
  recovery_link: PageLink;
  schedule: WithdrawalAckForm;
  deactivate: WithdrawalAckForm | null;
};

function AckSection({ form }: { form: WithdrawalAckForm }) {
  const [checked, setChecked] = useState(form.checked ?? false);
  const [processing, setProcessing] = useState(false);
  const { confirm: requestConfirmation, dialog } = useConfirm();

  const send = () => {
    const payload = { [form.field]: checked ? "1" : "0" };
    const options = {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    };

    if (form.method === "patch") {
      router.patch(form.url, payload, options);
    } else {
      router.get(form.url, payload, options);
    }
  };

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    // The acknowledgement step the server sent no confirmation copy for was never gated by one.
    if (form.confirm) {
      requestConfirmation({ message: form.confirm, confirmLabel: form.submit_label }, send);
      return;
    }
    send();
  };

  return (
    <section>
      <h2>{form.title}</h2>
      <ErrorList errors={form.errors} />

      <form onSubmit={submit}>
        <div>
          <input
            id={form.field}
            name={form.field}
            type="checkbox"
            checked={checked}
            onChange={(event) => setChecked(event.target.checked)}
          />
          <label htmlFor={form.field}>{form.ack_label}</label>
        </div>
        <button
          type="submit"
          disabled={processing}
        >
          {form.submit_label}
        </button>
      </form>
      {dialog}
    </section>
  );
}

export default function WithdrawalNew({
  title,
  already_deactivated: alreadyDeactivated,
  already_deactivated_message: alreadyDeactivatedMessage,
  recovery_link: recoveryLink,
  schedule,
  deactivate,
}: WithdrawalNewProps) {
  return (
    <section>
      <h1>{title}</h1>

      {alreadyDeactivated ? (
        <>
          <p>{alreadyDeactivatedMessage}</p>
          <p>
            <Link href={recoveryLink.href}>{recoveryLink.label}</Link>
          </p>
        </>
      ) : (
        <>
          <AckSection form={schedule} />
          {deactivate ? <AckSection form={deactivate} /> : null}
        </>
      )}
    </section>
  );
}
