import { router } from "@inertiajs/react";
import { useState } from "react";

type AddressForm = {
  action: string;
  label: string;
  address: string;
  submit_label: string;
};

type PassCodeForm = {
  action: string;
  label: string;
  submit_label: string;
};

type Props = {
  title: string;
  description: string;
  address_form: AddressForm;
  pass_code_form: PassCodeForm | null;
};

export default function WithdrawalSessionNew({
  title,
  description,
  address_form: addressForm,
  pass_code_form: passCodeForm,
}: Props) {
  const [address, setAddress] = useState(addressForm.address);
  const [passCode, setPassCode] = useState("");

  return (
    <section>
      <h1>{title}</h1>
      <p>{description}</p>

      <form
        onSubmit={(event) => {
          event.preventDefault();
          router.post(addressForm.action, { data: { withdrawal_reentry: { address } } });
        }}
      >
        <label htmlFor="withdrawal_reentry_address">{addressForm.label}</label>
        <input
          id="withdrawal_reentry_address"
          type="email"
          autoComplete="email"
          value={address}
          onChange={(event) => setAddress(event.target.value)}
        />
        <button type="submit">{addressForm.submit_label}</button>
      </form>

      {passCodeForm ? (
        <form
          onSubmit={(event) => {
            event.preventDefault();
            router.post(passCodeForm.action, { data: { pass_code: passCode } });
          }}
        >
          <label htmlFor="withdrawal_pass_code">{passCodeForm.label}</label>
          <input
            id="withdrawal_pass_code"
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={passCode}
            onChange={(event) => setPassCode(event.target.value)}
          />
          <button type="submit">{passCodeForm.submit_label}</button>
        </form>
      ) : null}
    </section>
  );
}
