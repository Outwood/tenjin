# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  protect_from_forgery
  before_action :configure_permitted_parameters, if: :devise_controller?
  after_action :verify_authorized, except: :index, unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :dashboard_style

  protected

  def configure_permitted_parameters
    added_attrs = %i[username email password password_confirmation remember_me school_id]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
  end

  def after_sign_in_path_for(resource)
    resource.is_a?(Admin) ? system_root_path : dashboard_path
  end

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back fallback_location: root_path
  end

  # The style the user has equipped, or nil for a signed-out visitor. Views
  # that want it ask for it, so no action has to remember to set it up.
  def dashboard_style
    return @dashboard_style if defined?(@dashboard_style)

    @dashboard_style = current_user && find_dashboard_style
  end

  def find_dashboard_style
    style = ActiveCustomisation.joins(:customisation)
      .find_by(user: current_user,
        customisations: {customisation_type: "dashboard_style"})
    return style.customisation if style.present?

    Customisation.find_by(customisation_type: "dashboard_style", value: "red")
  end

  def pundit_user
    current_user
  end

  # The namespace a record's policy is looked up in; namespaced controllers
  # override this rather than each of the three lookups below
  def pundit_namespace(record) = record

  def authorize(record, ...) = super(pundit_namespace(record), ...)

  def policy_scope(scope, ...) = super(pundit_namespace(scope), ...)

  def policy(record) = super(pundit_namespace(record))
end
