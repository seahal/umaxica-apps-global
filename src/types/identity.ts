// Prop shapes shared by the base/app identity pages.
//
// Rails resolves every label and URL, so these types describe finished strings and generated
// hrefs rather than keys or path fragments.

export type IdentityLink = {
  label: string;
  href: string;
};

export type IdentityDestructiveAction = {
  label: string;
  confirm: string;
  url: string;
};

export type IdentityPreferenceField = {
  checked: boolean;
  label: string;
  description: string;
};
