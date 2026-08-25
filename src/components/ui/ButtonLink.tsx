// A destination that carries the weight of a primary action.
//
// The "next step" on a settings index — add a passkey, register a telephone — is a link, not a
// button: it navigates. It was nonetheless being hand-styled to look like the primary button in
// five places, each with its own copy of the class string, so the two drifted apart. This is that
// link, wearing `Button`'s appearance from the same source.
import { Link } from "@inertiajs/react";
import type { ReactNode } from "react";

import { buttonClass, type ButtonSize, type ButtonVariant } from "@/components/ui/buttonStyles";

// Deliberately not `AnchorHTMLAttributes`: Inertia's `Link` accepts a different, narrower prop
// set, so a shared anchor-attribute surface would either fail to compile or quietly drop half of
// what a caller passed on the Inertia branch. These are the props the application actually uses.
export type ButtonLinkProps = {
  href: string;
  className?: string;
  children: ReactNode;
  variant?: ButtonVariant;
  size?: ButtonSize;
  /**
   * A client-side visit. Only for a destination on this surface: Inertia visits another origin over
   * XHR, which CORS rejects, and most of these destinations are cross-surface ceremonies.
   */
  inertia?: boolean;
};

export default function ButtonLink({
  variant = "primary",
  size = "md",
  inertia = false,
  className,
  children,
  href,
}: ButtonLinkProps) {
  const classes = [buttonClass(variant, size, "css"), className].filter(Boolean).join(" ");

  if (inertia) {
    return (
      <Link
        href={href}
        className={classes}
      >
        {children}
      </Link>
    );
  }

  return (
    <a
      href={href}
      className={classes}
    >
      {children}
    </a>
  );
}
