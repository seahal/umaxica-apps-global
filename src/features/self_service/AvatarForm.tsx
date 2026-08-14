// The avatar create/update form. The server sends the action URL, the HTTP verb the route expects
// and every label already translated, so the component only binds fields and reports errors.
import { useForm } from "@inertiajs/react";
import type { FormEvent } from "react";

export type AvatarFormProps = {
  title: string;
  heading: string;
  action: string;
  method: "post" | "patch";
  submit_label: string;
  moniker: { label: string; value: string; maxlength: number };
  // Present only on creation: the handle is immutable once the avatar exists.
  handle: { label: string; value: string; maxlength: number } | null;
};

export default function AvatarForm({
  title,
  heading,
  action,
  method,
  submit_label: submitLabel,
  moniker,
  handle,
}: AvatarFormProps) {
  const form = useForm({
    avatar: { moniker: moniker.value, handle: handle ? handle.value : "" },
  });
  const { data, setData, errors, processing } = form;

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (method === "post") {
      form.post(action);
    } else {
      form.patch(action);
    }
  };

  return (
    <section aria-label={title}>
      <h1>{heading}</h1>

      <form onSubmit={submit}>
        <div>
          <label htmlFor="avatar_moniker">{moniker.label}</label>
          <input
            id="avatar_moniker"
            name="avatar[moniker]"
            type="text"
            required
            maxLength={moniker.maxlength}
            value={data.avatar.moniker}
            onChange={(event) => setData("avatar", { ...data.avatar, moniker: event.target.value })}
          />
          {errors["avatar.moniker"] ? <p role="alert">{errors["avatar.moniker"]}</p> : null}
        </div>

        {handle ? (
          <div>
            <label htmlFor="avatar_handle">{handle.label}</label>
            <input
              id="avatar_handle"
              name="avatar[handle]"
              type="text"
              maxLength={handle.maxlength}
              value={data.avatar.handle}
              onChange={(event) =>
                setData("avatar", { ...data.avatar, handle: event.target.value })
              }
            />
            {errors["avatar.handle"] ? <p role="alert">{errors["avatar.handle"]}</p> : null}
          </div>
        ) : null}

        <button
          type="submit"
          disabled={processing}
        >
          {submitLabel}
        </button>
      </form>
    </section>
  );
}
