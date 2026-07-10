import { Application } from "@hotwired/stimulus";

const application = Application.start();

// Configure Stimulus development experience
const { hostname } = window.location;
const isLocalhost =
  hostname === "localhost" ||
  hostname === "127.0.0.1" ||
  hostname === "[::1]" ||
  hostname.endsWith(".localhost");
application.debug = isLocalhost;
window.Stimulus = application;

export { application };
