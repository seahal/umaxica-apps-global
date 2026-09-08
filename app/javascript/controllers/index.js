import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading";
import { application } from "controllers/application";

// The Importmap runtime resolves controller modules without Vite type metadata.
// oxlint-disable-next-line typescript/no-unsafe-call
eagerLoadControllersFrom("controllers", application);
