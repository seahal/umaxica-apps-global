import { router } from "@inertiajs/react";
import { useState } from "react";

type AppealForm = {
  url: string;
  reason_label: string;
  reason_codes: { label: string; value: string }[];
  statement_label: string;
  statement_max_length: number;
  submit_label: string;
};

type EnforcementCase = {
  public_id: string;
  kind_label: string;
  restore: { url: string; submit_label: string };
  appeal: AppealForm | null;
};

type Props = {
  title: string;
  description: string;
  appeal_error: string | null;
  enforcement_cases: EnforcementCase[];
};

function AppealSection({ form, casePublicId }: { form: AppealForm; casePublicId: string }) {
  const [reasonCode, setReasonCode] = useState(form.reason_codes[0]?.value ?? "");
  const [statement, setStatement] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(form.url, {
      data: {
        appeal: {
          enforcement_case_id: casePublicId,
          reason_code: reasonCode,
          statement,
        },
      },
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <form onSubmit={submit}>
      <label htmlFor={`appeal_reason_code_${casePublicId}`}>{form.reason_label}</label>
      <select
        id={`appeal_reason_code_${casePublicId}`}
        value={reasonCode}
        onChange={(event) => setReasonCode(event.target.value)}
      >
        {form.reason_codes.map((choice) => (
          <option
            key={choice.value}
            value={choice.value}
          >
            {choice.label}
          </option>
        ))}
      </select>

      <label htmlFor={`appeal_statement_${casePublicId}`}>{form.statement_label}</label>
      <textarea
        id={`appeal_statement_${casePublicId}`}
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

export default function RecoveryShow({
  title,
  description,
  appeal_error: appealError,
  enforcement_cases: enforcementCases,
}: Props) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      {appealError ? <p role="alert">{appealError}</p> : null}

      {enforcementCases.map((enforcementCase) => (
        <div key={enforcementCase.public_id}>
          <p>{enforcementCase.kind_label}</p>

          <form
            onSubmit={(event) => {
              event.preventDefault();
              router.post(enforcementCase.restore.url, {
                data: { enforcement_case_id: enforcementCase.public_id },
              });
            }}
          >
            <button type="submit">{enforcementCase.restore.submit_label}</button>
          </form>

          {enforcementCase.appeal ? (
            <AppealSection
              form={enforcementCase.appeal}
              casePublicId={enforcementCase.public_id}
            />
          ) : null}
        </div>
      ))}
    </section>
  );
}
