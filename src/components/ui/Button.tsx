// The one button.
//
// Wraps React Aria's `Button`, which owns the press, hover and focus behaviour that used to be
// hand-written: it normalises pointer, touch and keyboard activation, and exposes each state as a
// data attribute that the `tailwindcss-react-aria-components` plugin turns into a variant
// (`pressed:`, `hovered:`, `disabled:`). Nothing here re-implements any of that.
//
// The appearance itself lives in `./buttonStyles`, shared with `ButtonLink`.
//
// The focus ring is not declared here on purpose. `src/styles/theme.css` paints one
// `:focus-visible` outline for the whole document, so every focusable element agrees without each
// component restating it.
import { Button as AriaButton, type ButtonProps as AriaButtonProps } from "react-aria-components";

import { buttonClass, type ButtonSize, type ButtonVariant } from "@/components/ui/buttonStyles";

export type { ButtonSize, ButtonVariant };

export type ButtonProps = AriaButtonProps & {
  variant?: ButtonVariant;
  size?: ButtonSize;
};

export default function Button({
  variant = "primary",
  size = "md",
  className,
  ...props
}: ButtonProps) {
  // React Aria accepts a function for `className` so a caller can react to state. Resolving it here
  // keeps that contract working instead of silently dropping the caller's function.
  return (
    <AriaButton
      {...props}
      className={(renderProps) =>
        [
          buttonClass(variant, size, "aria"),
          typeof className === "function" ? className(renderProps) : className,
        ]
          .filter(Boolean)
          .join(" ")
      }
    />
  );
}
