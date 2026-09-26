# frozen_string_literal: true

namespace :homeworks do
  desc "Move due times typed in British Summer Time before the UK-time release back an hour. " \
    "CUTOFF=<release time, e.g. 2026-09-28T10:15Z> is required; PAST=1 includes homework already due; " \
    "APPLY=1 writes, otherwise it only counts"
  task rebase_summer_due_times: :environment do
    cutoff = ENV["CUTOFF"].presence && Time.zone.parse(ENV["CUTOFF"])
    abort "Set CUTOFF to when the UK-time release went live, e.g. CUTOFF=2026-09-28T10:15Z" if cutoff.nil?

    apply = ENV["APPLY"] == "1"
    counts = Homework::RebaseSummerDueTimes.call(cutoff: cutoff, include_past: ENV["PAST"] == "1", apply: apply)
    puts "Summer due times saved before #{cutoff.utc.iso8601}: #{counts[:upcoming]} upcoming, #{counts[:past]} past"
    puts "Completions on past homework that moving it would turn late: #{counts[:past_turning_late]}"
    puts apply ? "Moved #{counts[:moved]}" : "Dry run, nothing written; set APPLY=1 to move them"
  end
end
