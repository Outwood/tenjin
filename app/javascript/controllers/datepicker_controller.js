import { Controller } from "@hotwired/stimulus";
import flatpickr from "flatpickr";

// The label, hint and error name the field by id and aria attributes, which
// flatpickr leaves on the input it hides
const NAMING_ATTRIBUTES = ["id", "aria-describedby", "aria-invalid"];

export default class extends Controller {
  connect() {
    this.instance = flatpickr(this.element, {
      altInput: true,
      // As the app writes due times elsewhere: 5 Oct 2030, 09:00
      altFormat: "j M Y, H:i",
      enableTime: true,
      locale: { firstDayOfWeek: 1 },
      minDate: "today",
      time_24hr: true,
    });
    this.showPastValue();
    this.moveNaming(this.element, this.visibleInput);
  }

  disconnect() {
    this.moveNaming(this.visibleInput, this.element);
    this.instance?.destroy();
  }

  // flatpickr blanks a date before minDate, which the hidden input still submits
  showPastValue() {
    const { altInput, config, selectedDates } = this.instance;
    if (!altInput || selectedDates.length > 0 || !this.element.value) return;

    const date = this.instance.parseDate(this.element.value, config.dateFormat);
    if (date) altInput.value = this.instance.formatDate(date, config.altFormat);
  }

  // A phone shows a native picker in place of the alt input
  get visibleInput() {
    return this.instance?.mobileInput ?? this.instance?.altInput;
  }

  moveNaming(from, to) {
    if (!from || !to) return;

    NAMING_ATTRIBUTES.forEach((name) => {
      if (!from.hasAttribute(name)) return;

      to.setAttribute(name, from.getAttribute(name));
      from.removeAttribute(name);
    });
  }
}
