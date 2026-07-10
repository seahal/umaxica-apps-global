import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  back(event) {
    if (window.history.length > 1) {
      event.preventDefault();
      window.history.back();
    }
    // If window.history.length <= 1, it will follow the link (if it's a link with up_fallback)
  }
}
