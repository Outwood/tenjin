# frozen_string_literal: true

# Moves due times saved before the app ran on UK time back to the time the teacher typed. Those rows hold the
# typed clock time as UTC, so one typed during British Summer Time falls due an hour late; winter ones are right.
class Homework::RebaseSummerDueTimes < ApplicationService
  UK = ActiveSupport::TimeZone["London"]

  # cutoff is when the UK-time release went live. Nothing edits a homework after it is saved, so a row updated
  # since then is either new, and already right, or one this has moved, which keeps a second run from moving it again.
  def initialize(cutoff:, include_past: false, apply: false)
    @cutoff = cutoff
    @include_past = include_past
    @apply = apply
  end

  # Counts summer rows upcoming and past, the completions on past ones that moving them would turn late, and
  # the rows moved
  def call
    counts = {upcoming: 0, past: 0, past_turning_late: 0, moved: 0}
    Homework.where(updated_at: ...@cutoff).find_each do |homework|
      typed = typed_time(homework.due_date)
      next if typed == homework.due_date

      if homework.due_date.past?
        counts[:past] += 1
        counts[:past_turning_late] += homework.homework_progresses
          .where("completed_at > ? AND completed_at <= ?", typed, homework.due_date).count
        next unless @include_past
      else
        counts[:upcoming] += 1
      end
      next unless @apply

      homework.update_columns(due_date: typed, updated_at: Time.current)
      counts[:moved] += 1
    end
    counts
  end

  private

  # The stored UTC clock reading, read instead as UK time
  def typed_time(stored)
    utc = stored.utc
    UK.local(utc.year, utc.month, utc.day, utc.hour, utc.min, utc.sec)
  end
end
