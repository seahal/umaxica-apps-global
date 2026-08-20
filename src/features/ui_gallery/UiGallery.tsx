// Every shared primitive on one page, for the dev surface only.
//
// This replaces the old "React Aria probe", which demonstrated a shim that only looked like React
// Aria: it exported a hand-written `Button` and a `TextField` that was a bare `<div>`, so the page
// proved nothing about the library it was named after.
//
// What it is for now: rendering each primitive in one place is how the visual states that no unit
// test can assert — the focus ring, the dark palette, contrast, the overlay's position — get
// checked in a real browser. It ships only on `core/dev`.
import { useState } from "react";

import Button, { type ButtonVariant } from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import Dialog from "@/components/ui/Dialog";
import RadioGroup from "@/components/ui/RadioGroup";
import Select from "@/components/ui/Select";
import TextField from "@/components/ui/TextField";

const VARIANTS: ButtonVariant[] = ["primary", "secondary", "danger", "ghost"];

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4">
      <h2 className="text-sm font-semibold tracking-wide text-fg-muted uppercase">{title}</h2>
      {children}
    </section>
  );
}

export function UiGallery(_props: Record<string, unknown>) {
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6 p-6">
      <header className="flex flex-col gap-1">
        <p className="text-xs font-medium tracking-wide text-fg-muted uppercase">
          Internal, dev surface only
        </p>
        <h1 className="text-2xl font-bold text-fg">UI primitives</h1>
        <p className="text-sm text-fg-muted">
          Each primitive below is the one the application uses. Switch the theme control in the
          footer to check the dark palette, and tab through the page to check the focus ring.
        </p>
      </header>

      <Section title="Button">
        <div className="flex flex-wrap items-center gap-2">
          {VARIANTS.map((variant) => (
            <Button
              key={variant}
              variant={variant}
            >
              {variant}
            </Button>
          ))}
          <Button isDisabled>disabled</Button>
        </div>
      </Section>

      <Section title="TextField">
        <TextField
          label="Address"
          description="Bound to its description through aria-describedby."
          placeholder="you@example.com"
          type="email"
        />
        <TextField
          label="Rejected address"
          errorMessage="The server rejected this address."
          defaultValue="not-an-address"
          type="email"
        />
        <TextField
          label="Disabled"
          isDisabled
          defaultValue="unavailable"
        />
      </Section>

      <Section title="Select">
        <Select
          label="Theme"
          defaultValue="system"
          options={[
            { value: "system", label: "Follow the system" },
            { value: "light", label: "Light" },
            { value: "dark", label: "Dark" },
          ]}
        />
      </Section>

      <Section title="Checkbox and RadioGroup">
        <Checkbox defaultSelected>Functional cookies</Checkbox>
        <Checkbox>Performance cookies</Checkbox>
        <Checkbox isDisabled>Unavailable</Checkbox>

        <RadioGroup
          label="Delivery"
          defaultValue="email"
          options={[
            { value: "email", label: "Email", description: "The address on the account." },
            { value: "sms", label: "SMS" },
            { value: "none", label: "Nothing", isDisabled: true },
          ]}
        />
      </Section>

      <Section title="Dialog">
        <div>
          <Button onPress={() => setDialogOpen(true)}>Open the dialog</Button>
        </div>
        <Dialog
          title="Is the overlay positioned and trapped?"
          isOpen={dialogOpen}
          onOpenChange={setDialogOpen}
        >
          <p className="text-sm text-fg-muted">
            Tab should stay inside this dialog, Escape should close it, and focus should return to
            the control that opened it.
          </p>
          <div className="flex justify-end">
            <Button
              autoFocus
              variant="secondary"
              onPress={() => setDialogOpen(false)}
            >
              Close
            </Button>
          </div>
        </Dialog>
      </Section>
    </div>
  );
}
