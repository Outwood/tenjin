# frozen_string_literal: true

# Enforces NOT NULL on the question and answer columns every question type
# relies on.
#
# Each column gets a NOT VALID CHECK constraint first, which rejects new NULLs
# from that point on. Validating the CHECK lets Postgres set NOT NULL without
# a full table scan; the CHECK is then redundant.
#
# Every step is idempotent so a rerun after a lock timeout resumes cleanly.
class EnforceNotNullOnQuestionColumns < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  COLUMNS = [
    [:answers, :text],
    [:questions, :active],
    [:questions, :question_type]
  ].freeze

  def up
    execute "SET lock_timeout TO '10s'"

    COLUMNS.each { |table, column| enforce_not_null(table, column) }
  end

  def down
    COLUMNS.each { |table, column| change_column_null table, column, true }
  end

  private

  def enforce_not_null(table, column)
    return if connection.columns(table).find { |c| c.name == column.to_s }&.null == false

    constraint_name = "#{table}_#{column}_not_null"
    expression = "#{connection.quote_column_name(column)} IS NOT NULL"

    unless check_constraint_exists?(table, name: constraint_name)
      add_check_constraint table, expression, name: constraint_name, validate: false
    end
    validate_check_constraint table, name: constraint_name
    change_column_null table, column, false
    remove_check_constraint table, name: constraint_name
  end
end
