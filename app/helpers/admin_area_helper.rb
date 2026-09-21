# frozen_string_literal: true

# Page furniture shared by the admin area's views
module AdminAreaHelper
  # Each colour is an .admin-avatar-N class in admin.scss, so the count must match; changing it recolours every admin
  AVATAR_COLOURS = 16

  # Colours the account avatar, so two admins whose emails share an initial still tell apart
  def admin_avatar_class(admin)
    "admin-avatar-#{admin.id % AVATAR_COLOURS}"
  end

  # Titles the tab and heads the page; breadcrumbs are [label, path] pairs leading to it, and the block yields its actions
  def admin_page_header(title, breadcrumbs: [], &actions)
    content_for(:title) { tag.title("#{title} · Tenjin admin") }
    render "system/page_header", title: title, breadcrumbs: breadcrumbs, actions: actions && capture(&actions)
  end

  # The Settings menu's [label, path] pairs, limited to what this admin may reach
  def settings_menu_items
    items = []
    items << ["Admins", system_admins_path] if admin_policy(Admin).index?
    items << ["School Groups", system_school_groups_path] if admin_policy(SchoolGroup).index?
    items << ["Maintenance", system_maintenance_path] if admin_policy(:maintenance).show?
    items
  end

  private

  # The public layout renders the admin navigation for a signed-in admin, where
  # `policy` reaches neither the System:: policies nor current_admin. Naming a
  # policy_class mirrors the controllers, for the nested resources whose policy
  # does not follow from their record class
  def admin_policy(record, policy_class: nil)
    return policy_class.new(current_admin, record) if policy_class

    Pundit.policy!(current_admin, [:system, record])
  end
end
