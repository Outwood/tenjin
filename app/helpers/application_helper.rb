# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  FLASH_CLASSES = {
    "success" => "alert-success",
    "error" => "alert-danger",
    "alert" => "alert-danger",
    "notice" => "alert-info"
  }.freeze

  def bootstrap_flash_class(type)
    FLASH_CLASSES.fetch(type, "alert-warning")
  end

  # A tick or a cross, named for screen readers by the label for its state
  def boolean_icon(status, yes: "Yes", no: "No")
    status ? status_icon("fas fa-check text-success", yes) : status_icon("fas fa-times text-danger", no)
  end

  # An icon that shows a state, with hidden text naming it
  def status_icon(icon, label)
    content_tag(:i, nil, class: icon, aria: {hidden: true}) + content_tag(:span, label, class: "visually-hidden")
  end

  # Links a navigation item, marking the current section for both styling and screen readers; css_class is the base
  # class. Only a link to the page itself is the current page: on a page nested under it, it is the current section.
  def nav_link(label, path, current:, css_class: "nav-link")
    aria_current = current_page?(path) ? "page" : "true" if current
    link_to label, path, class: [css_class, {active: current}], aria: {current: aria_current}
  end

  # The rule under a section heading; pass dashboard_style to colour it with the user's own
  def render_small_separator(style = nil, margin: "mb-5")
    color = style&.value || "red"
    content_tag(:div, nil, class: "heading-divider #{margin}", style: "color: #{color}", aria: {hidden: true})
  end

  def render_dashboard_style(style)
    return "" if style.nil?
    return "" unless style.image.attached?

    "background:linear-gradient(rgba(0, 0, 0, 0.4), rgba(0, 0, 0, 0.5)), url(#{rails_blob_url(style.image)}) no-repeat;"
  end

  # A CSV download named for what it lists; a class name like 9X/Sc carries a path separator,
  # which each browser would otherwise replace with a character of its own choosing
  def csv_filename(name)
    "#{name.gsub(%r{[/\\:*?"<>|]+}, "-")}.csv"
  end

  def user_class_names(student)
    student.enrollments.map { |e| e.classroom.name }.join(", ")
  end

  def add_row_button(name, form, association, partial: association.to_s.singularize, **args)
    new_object = form.object.send(association).klass.new
    id = new_object.object_id
    fields = form.simple_fields_for(association, new_object, child_index: id) do |builder|
      render(partial, f: builder)
    end
    button_tag(name, type: "button",
      class: args[:class].to_s,
      data: {action: "click->nested-fields#add", id: id, fields: fields.delete("\n")})
  end
end
