# frozen_string_literal: true

# Runs the checks Postgres defers to commit, which a transactional example never reaches
module DeferredConstraints
  def check_deferred_constraints!
    ActiveRecord::Base.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
  end
end

RSpec.configure { |config| config.include DeferredConstraints, type: :model }
