import { router } from "@inertiajs/react";
import { useState } from "react";

// Replaces `app/views/base/com/identity/recoveries/show.html.erb`. Whether a case may be appealed
// is decided on the server: an unappealable case simply arrives without an appeal form.

export type RecoveryAppealForm = {
  url: string;
  scope: string;
  reason_label: string;
  reason_codes: { label: string; value: string }[];
  statement_label: string;
  statement_max_length: number;
  submit_label: string;
};

export type RecoveryCase = {
  public_id: string;
  kind_label: string;
  restore: { url: string; submit_label: string };
  appeal: RecoveryAppealForm | null;
};

export type EnforcementRecoveryShowProps = {
  title: string;
  description: string;
  appeal_error: string | null;
  enforcement_cases: RecoveryCase[];
};

function RestoreForm({
  action,
  enforcementCaseId,
}: {
  action: { url: string; submit_label: string };
  enforcementCaseId: string;
}) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      action.url,
      { enforcement_case_id: enforcementCaseId },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <form onSubmit={submit}>
      <button
        type="submit"
        disabled={processing}
      >
        {action.submit_label}
      </button>
    </form>
  );
}

function AppealForm({
  form,
  enforcementCaseId,
}: {
  form: RecoveryAppealForm;
  enforcementCaseId: string;
}) {
  const [reasonCode, setReasonCode] = useState(form.reason_codes[0]?.value ?? "");
  const [statement, setStatement] = useState("");
  const [processing, setProcessing] = useState(false);

  const reasonId = `${form.scope}_${enforcementCaseId}_reason_code`;
  const statementId = `${form.scope}_${enforcementCaseId}_statement`;

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        [form.scope]: {
          enforcement_case_id: enforcementCaseId,
          reason_code: reasonCode,
          statement,
        },
      },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <form onSubmit={submit}>
      <label htmlFor={reasonId}>{form.reason_label}</label>
      <select
        id={reasonId}
        name={`${form.scope}[reason_code]`}
        value={reasonCode}
        onChange={(event) => setReasonCode(event.target.value)}
      >
        {form.reason_codes.map((code) => (
          <option
            key={code.value}
            value={code.value}
          >
            {code.label}
          </option>
        ))}
      </select>

      <label htmlFor={statementId}>{form.statement_label}</label>
      <textarea
        id={statementId}
        name={`${form.scope}[statement]`}
        maxLength={form.statement_max_length}
        value={statement}
        onChange={(event) => setStatement(event.target.value)}
      />

      <button
        type="submit"
        disabled={processing}
      >
        {form.submit_label}
      </button>
    </form>
  );
}

export default function EnforcementRecoveryShow({
  title,
  description,
  appeal_error: appealError,
  enforcement_cases: enforcementCases,
}: EnforcementRecoveryShowProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>
      {appealError ? <p role="alert">{appealError}</p> : null}

      {enforcementCases.map((enforcementCase) => (
        <section key={enforcementCase.public_id}>
          <p>{enforcementCase.kind_label}</p>
          <RestoreForm
            action={enforcementCase.restore}
            enforcementCaseId={enforcementCase.public_id}
          />
          {enforcementCase.appeal ? (
            <AppealForm
              form={enforcementCase.appeal}
              enforcementCaseId={enforcementCase.public_id}
            />
          ) : null}
        </section>
      ))}
    </section>
  );
}
