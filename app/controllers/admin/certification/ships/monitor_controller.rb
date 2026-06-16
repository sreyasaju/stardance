class Admin::Certification::Ships::MonitorController < Admin::Certification::ApplicationController
  def show
    authorize :monitor, policy_class: Admin::Certification::Ships::MonitorPolicy
    @stats     = Certification::Ship.dashboard_stats
    @reviewers = Certification::Ship.reviewer_stats
  end
end
