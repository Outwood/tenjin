# frozen_string_literal: true

module ClassroomsHelper
  SYNC_REFRESH_MESSAGE = "Refresh the page to see the current sync status"

  def student_homeworks(student, homework_progress)
    entries = homework_progress.select { |hp| hp.user_id == student.id }
    safe_join(entries.take(5).map { |e| boolean_icon(e.completed?) })
  end

  def report_progress(homework)
    count = homework.count
    return "0 / 0 - 0%" if count.zero?

    percent = number_to_percentage(homework.completed_count / count.to_f * 100, precision: 0)
    "#{homework.completed_count} / #{count} - #{percent}"
  end

  private
end
