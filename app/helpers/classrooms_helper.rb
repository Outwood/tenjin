# frozen_string_literal: true

module ClassroomsHelper
  # The page flips to this sentence itself the moment a subject changes
  SYNC_NEEDED_NOTICE = "Sync needed: pupils join a mapped class on the next sync."
  SYNC_RUNNING_NOTICE = "Sync running. Refresh the page to see its progress."

  # One sentence on the roster sync for the classrooms page, which sends the admin to
  # the school page to run it
  def sync_notice(school)
    case school.sync_status
    when "never" then "Never synced. Run the first sync from the school page."
    when "successful" then school.last_sync ? "Last synced #{school.last_sync.strftime("%-d %b %Y")}." : "Synced."
    when "needed" then SYNC_NEEDED_NOTICE
    when "failed" then "Last sync failed."
    when "queued" then SYNC_RUNNING_NOTICE
    when "syncing" then school.sync_stalled? ? "Last sync timed out." : SYNC_RUNNING_NOTICE
    else "Sync status unknown."
    end
  end

  # The icon and wording for each state Homework#state_for gives
  HOMEWORK_SLOTS = {
    done: {icon: "fas fa-check text-success", text: "done"},
    done_late: {icon: "fas fa-check text-warning-emphasis", text: "done late"},
    overdue: {icon: "fas fa-exclamation text-danger", text: "overdue"},
    not_due: {icon: "far fa-circle text-secondary", text: "not yet due"},
    not_set: {icon: "fas fa-minus text-body-tertiary", text: "set before they joined"}
  }.freeze

  # One slot per homework in the order given, so each homework's slots line up down the class;
  # progress maps a homework's id to the pupil's row on it
  def homework_strip(homeworks, progress)
    safe_join(homeworks.map { |homework| homework_slot(homework, progress[homework.id]) }, " ")
  end

  # The icon says the state at a glance; the title and hidden text name the homework
  def homework_slot(homework, progress)
    slot = HOMEWORK_SLOTS.fetch(homework.state_for(progress))
    label = "#{homework.topic.name}, due #{homework.due_date.strftime("%-d %b")}: #{slot[:text]}"
    content_tag(:span, class: "homework-slot", title: label, data: {homework: homework.id}) do
      content_tag(:i, nil, class: "#{slot[:icon]} fa-fw", aria: {hidden: true}) +
        content_tag(:span, label, class: "visually-hidden")
    end
  end

  # A pupil's state on the homework, in words beside its icon
  def homework_status(homework, progress)
    slot = HOMEWORK_SLOTS.fetch(homework.state_for(progress))
    content_tag(:i, nil, class: "#{slot[:icon]} fa-fw me-1", aria: {hidden: true}) + slot[:text].upcase_first
  end

  # Leads with the percentage, which the classroom page sorts the column by
  def report_progress(homework)
    count = homework.count
    return "No pupils" if count.zero?

    percent = number_to_percentage(homework.completed_count / count.to_f * 100, precision: 0)
    "#{percent} (#{homework.completed_count} of #{count})"
  end

  # The due time is the clock time the teacher entered, stored without a zone, so the datetime carries none
  def homework_due_time(homework)
    tag.time(homework.due_date.strftime("%-d %b %Y, %H:%M"), datetime: homework.due_date.strftime("%Y-%m-%dT%H:%M"))
  end

  private
end
