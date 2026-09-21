# frozen_string_literal: true

# The admin area's user list, filtered by name, account type, held role and school.
class User::Directory
  def initialize(scope:, search: nil, type: nil, role: nil, school: nil)
    @scope = scope
    @search = search.presence
    @type = type.presence
    @role = role.presence
    @school = school.presence
  end

  def users
    @users ||= by_school(by_role(by_type(by_search(@scope))))
      .includes(:school)
      .order(:surname, :forename)
  end

  private

  def by_search(scope)
    return scope if @search.nil?

    scope.where(
      "users.forename ILIKE :term OR users.surname ILIKE :term OR users.username ILIKE :term",
      term: "%#{@search}%"
    )
  end

  def by_type(scope) = @type.nil? ? scope : scope.where(role: @type)

  def by_role(scope) = @role.nil? ? scope : scope.holding_role(@role)

  def by_school(scope) = @school.nil? ? scope : scope.where(school_id: @school)
end
