# frozen_string_literal: true

# Formats the challenge and homework tables on a pupil's dashboard and user page
module DashboardHelper
  include ClassroomsHelper

  def challenge_progress_display(challenge, challenge_progresses)
    challenge_progress = challenge_progresses.select { |cp| cp.challenge_id == challenge.id }
    return "0%" if challenge_progress.empty?
    return status_icon("fas fa-check text-success", "Complete") if challenge_progress.first.completed

    challenge_progress.first.progress.to_s
  end

  # The states are the class page's (ClassroomsHelper#homework_state), with icons for this
  # table's dark background; a pupil's own table has a row for every homework, so none is unset
  PUPIL_HOMEWORK_ICONS = {
    done: {icon: "fas fa-check text-success", text: "Complete"},
    done_late: {icon: "fas fa-check text-warning", text: "Complete, late"},
    overdue: {icon: "fas fa-exclamation text-warning", text: "Overdue"},
    not_due: {icon: "fas fa-times text-danger", text: "Not complete"}
  }.freeze

  def homework_status_icon(homework_progress)
    state = PUPIL_HOMEWORK_ICONS.fetch(homework_state(homework_progress.homework, homework_progress))
    status_icon(state[:icon], state[:text])
  end

  def challenge_time_left(challenge)
    return "Ended" if challenge.end_date.past?

    distance_of_time_in_words(Time.current, challenge.end_date)
  end
end
