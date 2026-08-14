// The sign-up checkpoint: the requirements still standing between a verified contact and a
// finished registration.
//
// Which requirements are missing is a server decision made from the ticket, so a section is absent
// rather than hidden, and the cancellation endpoint is the one the server chose for the current
// step. The checkpoint version travels as a plain integer the server re-validates on submission.
import BirthdateFieldset, { type BirthdateFieldsetProps } from "./BirthdateFieldset";
import { csrfToken } from "./csrf";

export type SignUpCheckpointRequirementLink = {
  title: string;
  description: string;
  label: string;
  href: string;
};

export type SignUpCheckpointBirthdate = {
  title: string;
  description: string;
  label: string;
  action: string;
  submit_label: string;
  checkpoint_version: number;
  fields: Omit<BirthdateFieldsetProps, "labelledby">;
};

export type SignUpCheckpointProps = {
  title: string;
  birthdate: SignUpCheckpointBirthdate | null;
  passkey: SignUpCheckpointRequirementLink | null;
  passcode: SignUpCheckpointRequirementLink | null;
  complete_message: string | null;
  cancellation: { label: string; action: string } | null;
};

function RequirementLink({ title, description, label, href }: SignUpCheckpointRequirementLink) {
  return (
    <section>
      <h2>{title}</h2>
      <p>{description}</p>
      <a href={href}>{label}</a>
    </section>
  );
}

export default function SignUpCheckpoint({
  title,
  birthdate,
  passkey,
  passcode,
  complete_message: completeMessage,
  cancellation,
}: SignUpCheckpointProps) {
  return (
    <section>
      <h1>{title}</h1>

      {birthdate ? (
        <section>
          <h2>{birthdate.title}</h2>
          <p>{birthdate.description}</p>

          <form
            action={birthdate.action}
            method="post"
            data-turbo="false"
          >
            <input
              type="hidden"
              name="_method"
              value="patch"
            />
            <input
              type="hidden"
              name="authenticity_token"
              value={csrfToken()}
            />
            <input
              type="hidden"
              name="requirement"
              value="birthdate"
            />
            <input
              type="hidden"
              name="checkpoint_version"
              value={birthdate.checkpoint_version}
            />

            <div>
              <p id="birthdate_label">{birthdate.label}</p>
              <BirthdateFieldset
                {...birthdate.fields}
                labelledby="birthdate_label"
              />
            </div>

            <input
              type="submit"
              value={birthdate.submit_label}
            />
          </form>
        </section>
      ) : null}

      {passkey ? <RequirementLink {...passkey} /> : null}
      {passcode ? <RequirementLink {...passcode} /> : null}

      {completeMessage ? <p>{completeMessage}</p> : null}

      {cancellation ? (
        <form
          action={cancellation.action}
          method="post"
          data-turbo="false"
        >
          <input
            type="hidden"
            name="_method"
            value="delete"
          />
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
          />
          <button type="submit">{cancellation.label}</button>
        </form>
      ) : null}
    </section>
  );
}
