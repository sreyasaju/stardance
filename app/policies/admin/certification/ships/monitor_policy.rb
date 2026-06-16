class Admin::Certification::Ships::MonitorPolicy < ApplicationPolicy
  def show? = user&.admin?
end
