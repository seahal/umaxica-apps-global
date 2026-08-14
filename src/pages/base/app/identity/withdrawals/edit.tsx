import { Link, router } from "@inertiajs/react";

import type { IdentityLink } from "@/types/identity";

type RecoverySection = {
  available_message: string | null;
  submit_label: string | null;
  confirm: string | null;
  action: string | null;
  unavailable_message: string | null;
};

type TerminationSection = {
  submit_label: string | null;
  confirm: string | null;
  action: string | null;
  available_at_message: string | null;
};

type Props = {
  title: string;
  terminated: boolean;
  unavailable_message: string;
  deadline_message: string | null;
  recovery: RecoverySection | null;
  termination: TerminationSection | null;
  erasure_link: IdentityLink;
  sign_out: { label: string; url: string };
};

export default function WithdrawalEdit({
  title,
  terminated,
  unavailable_message: unavailableMessage,
  deadline_message: deadlineMessage,
  recovery,
  termination,
  erasure_link: erasureLink,
  sign_out: signOut,
}: Props) {
  const signOutNow = () => router.delete(signOut.url);

  if (terminated) {
    return (
      <section>
        <h1>{title}</h1>
        <p>{unavailableMessage}</p>
        <button
          type="button"
          onClick={signOutNow}
        >
          {signOut.label}
        </button>
      </section>
    );
  }

  return (
    <section>
      <h1>{title}</h1>

      {deadlineMessage ? <p>{deadlineMessage}</p> : null}

      {recovery ? (
        <>
          {recovery.available_message ? <p>{recovery.available_message}</p> : null}
          {recovery.unavailable_message ? <p>{recovery.unavailable_message}</p> : null}
          {recovery.action && recovery.submit_label ? (
            <button
              type="button"
              onClick={() => {
                if (recovery.confirm && !window.confirm(recovery.confirm)) {
                  return;
                }
                router.post(recovery.action as string);
              }}
            >
              {recovery.submit_label}
            </button>
          ) : null}
        </>
      ) : null}

      {termination ? (
        <>
          {termination.available_at_message ? <p>{termination.available_at_message}</p> : null}
          {termination.action && termination.submit_label ? (
            <button
              type="button"
              onClick={() => {
                if (termination.confirm && !window.confirm(termination.confirm)) {
                  return;
                }
                router.delete(termination.action as string);
              }}
            >
              {termination.submit_label}
            </button>
          ) : null}
        </>
      ) : null}

      <p>
        <Link href={erasureLink.href}>{erasureLink.label}</Link>
      </p>

      <p>
        <button
          type="button"
          onClick={signOutNow}
        >
          {signOut.label}
        </button>
      </p>
    </section>
  );
}
