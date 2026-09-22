# frozen_string_literal: true

# Renders a user's account state for the admin user page
module UsersHelper
  def user_status_badge(user)
    label, colour = user.disabled? ? ["Inactive", "secondary"] : ["Active", "success"]
    tag.span(label, class: "badge text-bg-#{colour}")
  end

  # Devise's current_sign_in_at is the most recent sign-in; its last_sign_in_at is the one before
  def last_sign_in(user)
    time = user.current_sign_in_at
    return "Never" if time.nil?

    safe_join([
      time_tag(time, "#{time_ago_in_words(time)} ago"),
      tag.small(time.strftime("%-d %b %Y %H:%M"), class: "text-body-secondary ms-2")
    ])
  end
end
