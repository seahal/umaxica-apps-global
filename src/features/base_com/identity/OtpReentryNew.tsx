import { router } from "@inertiajs/react";
import { useState } from "react";

// The email re-entry screen shared by the withdrawal ceremony and the enforcement recovery
// ceremony: one form asks for the address, and the code form appears only once the server says a
// code has been issued.

export type ReentryAddressForm = {
  url: string;
  scope: string;
  field: string;
  label: string;
  value: string;
  submit_label: string;
};

export type ReentryPassCodeForm = {
  url: string;
  field: string;
  label: string;
  submit_label: string;
};

export type OtpReentryNewProps = {
  title: string;
  description?: string;
  generic_message?: string;
  address_form: ReentryAddressForm;
  pass_code_form: ReentryPassCodeForm | null;
};

export default function OtpReentryNew({
  title,
  description,
  generic_message: genericMessage,
  address_form: addressForm,
  pass_code_form: passCodeForm,
}: OtpReentryNewProps) {
  const [address, setAddress] = useState(addressForm.value);
  const [passCode, setPassCode] = useState("");
  const [processing, setProcessing] = useState(false);

  const message = description ?? genericMessage;
  const addressId = `${addressForm.scope}_${addressForm.field}`;

  const submitAddress = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      addressForm.url,
      { [addressForm.scope]: { [addressForm.field]: address } },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  const submitPassCode = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!passCodeForm) {
      return;
    }
    router.post(
      passCodeForm.url,
      { [passCodeForm.field]: passCode },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <section>
      <h1>{title}</h1>
      {message ? <p>{message}</p> : null}

      <form onSubmit={submitAddress}>
        <label htmlFor={addressId}>{addressForm.label}</label>
        <input
          id={addressId}
          name={`${addressForm.scope}[${addressForm.field}]`}
          type="email"
          autoComplete="email"
          value={address}
          onChange={(event) => setAddress(event.target.value)}
        />
        <button
          type="submit"
          disabled={processing}
        >
          {addressForm.submit_label}
        </button>
      </form>

      {passCodeForm ? (
        <form onSubmit={submitPassCode}>
          <label htmlFor={passCodeForm.field}>{passCodeForm.label}</label>
          <input
            id={passCodeForm.field}
            name={passCodeForm.field}
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={passCode}
            onChange={(event) => setPassCode(event.target.value)}
          />
          <button
            type="submit"
            disabled={processing}
          >
            {passCodeForm.submit_label}
          </button>
        </form>
      ) : null}
    </section>
  );
}
