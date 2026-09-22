# frozen_string_literal: true

class SchoolPolicy < ApplicationPolicy
  # A school admin runs their own school: its page, its roster sync and its password reset
  def show?
    user.has_role?(:school_admin) && user.school == record
  end

  alias_method :sync?, :show?
  alias_method :reset_all_passwords?, :show?
end
