# frozen_string_literal: true

# Keeps what a pupil answered on the attempt row: the option chosen, the
# text as they saw it, and when.
class AddResponseToAskedQuestions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute "SET lock_timeout TO '10s'"

    add_column :asked_questions, :answer_id, :bigint
    add_column :asked_questions, :response, :jsonb
    add_column :asked_questions, :answered_at, :datetime

    # An author's edit deletes answers, which must not fail on an attempt that chose one
    add_foreign_key :asked_questions, :answers, on_delete: :nullify, validate: false
    validate_foreign_key :asked_questions, :answers

    add_index :asked_questions, :answer_id, algorithm: :concurrently
    add_index :asked_questions, :answered_at, where: "answered_at IS NOT NULL", algorithm: :concurrently
  end

  def down
    remove_column :asked_questions, :answered_at
    remove_column :asked_questions, :response
    remove_column :asked_questions, :answer_id
  end
end
