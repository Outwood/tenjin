# frozen_string_literal: true

# Adds a school from Wonde, or returns it unsaved with the reason Wonde gave none
class School::AddSchool < ApplicationService
  # 403 is a real school the token has not been granted
  STATUS_ERRORS = {
    401 => [:token, :refused_by_wonde],
    403 => [:client_id, :not_on_wonde],
    404 => [:client_id, :not_on_wonde]
  }.freeze

  def initialize(school_params)
    @school_id = school_params[:client_id]
    @client_token = school_params[:token]
  end

  def call
    return unsaved(:client_id, :blank) if @school_id.blank?
    return unsaved(:token, :blank) if @client_token.blank?

    school_from_client = Wonderment::Client.new(@client_token).get("schools", @school_id)
    school = School.from_wonde(school_from_client, @client_token)
    school.permitted = true
    school.save!
    school
  rescue Wonderment::Error => e
    unsaved(*STATUS_ERRORS.fetch(e.status, [:base, :wonde_unavailable]))
  end

  private

  def unsaved(attribute, error)
    School.new(client_id: @school_id, token: @client_token).tap { |school| school.errors.add(attribute, error) }
  end
end
