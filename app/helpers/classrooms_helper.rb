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
