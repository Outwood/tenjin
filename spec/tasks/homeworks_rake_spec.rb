# frozen_string_literal: true

require "rails_helper"
require "rake"

# What the task moves is covered in spec/services/homework/rebase_summer_due_times_spec.rb
RSpec.describe "homeworks rake tasks" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("homeworks:rebase_summer_due_times") }

  around do |example|
    saved = %w[CUTOFF PAST APPLY].to_h { |name| [name, ENV.delete(name)] }
    example.run
  ensure
    saved.each { |name, value| value ? ENV[name] = value : ENV.delete(name) }
  end

  def run_task
    Rake::Task["homeworks:rebase_summer_due_times"].tap(&:reenable).invoke
  end

  describe "homeworks:rebase_summer_due_times" do
    it "refuses to run without the release time" do
      expect { run_task }.to raise_error(SystemExit).and output(/CUTOFF/).to_stderr
    end

    it "refuses a release time it can't read" do
      ENV["CUTOFF"] = "after lunch"
      expect { run_task }.to raise_error(SystemExit).and output(/CUTOFF/).to_stderr
    end

    it "counts without writing unless told to apply" do
      ENV["CUTOFF"] = "2026-09-28T10:15Z"
      expect { run_task }.to output(/0 upcoming, 0 past.*nothing written; set APPLY=1/m).to_stdout
    end
  end
end
