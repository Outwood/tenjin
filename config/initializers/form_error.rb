# Marks a field that has errors and puts that field's own messages beneath it
ActionView::Base.field_error_proc = proc do |html_tag, instance_tag|
  fragment = Nokogiri::HTML.fragment(html_tag)
  field = fragment.at("input:not([type=hidden]),select,textarea,trix-editor")
  next html_tag unless field

  field["class"] = "#{field["class"]} is-invalid".strip
  message = ERB::Util.html_escape(instance_tag.error_message.to_sentence)
  "#{fragment}<p class=\"error\">#{message}</p>".html_safe
end
