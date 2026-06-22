import { Button, TextField } from "react-aria-components";

import "./react_aria_probe.css";

export function ReactAriaProbe(_props: Record<string, unknown>) {
  return (
    <section
      aria-labelledby="react-aria-probe-title"
      className="react-aria-probe"
      data-react-aria-probe
    >
      <div className="react-aria-probe__shell">
        <p className="react-aria-probe__eyebrow">Internal demo only</p>
        <h1
          id="react-aria-probe-title"
          className="react-aria-probe__title"
        >
          React Aria probe
        </h1>
        <p className="react-aria-probe__copy">
          This page exists only to prove a tiny React island can mount inside the Rails app.
        </p>

        <div className="react-aria-probe__stack">
          <TextField
            className="react-aria-probe__field"
            validationState="invalid"
          >
            <label
              className="react-aria-probe__label"
              htmlFor="react-aria-probe-name"
            >
              Probe field
            </label>
            <input
              className="react-aria-probe__input"
              defaultValue="demo-only"
              id="react-aria-probe-name"
            />
            <p className="react-aria-probe__hint">
              Intentionally invalid for state styling coverage.
            </p>
          </TextField>

          <div className="react-aria-probe__actions">
            <Button className="react-aria-probe__button">Press me</Button>
            <Button
              className="react-aria-probe__button"
              isDisabled
            >
              Disabled
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
}
