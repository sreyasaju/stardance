# == Schema Information
#
# Table name: vote_assignments
#
#  id            :bigint           not null, primary key
#  status        :string           default("assigned"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ship_event_id :bigint           not null
#  user_id       :bigint           not null
#  vote_id       :bigint
#
# Indexes
#
#  index_vote_assignments_on_ship_event_id              (ship_event_id)
#  index_vote_assignments_on_user_id                    (user_id)
#  index_vote_assignments_on_user_id_and_ship_event_id  (user_id,ship_event_id) UNIQUE
#  index_vote_assignments_on_user_id_and_status         (user_id,status)
#  index_vote_assignments_on_vote_id                    (vote_id)
#
# Foreign Keys
#
#  fk_rails_...  (ship_event_id => post_ship_events.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (vote_id => votes.id)
#
class Vote::Assignment < ApplicationRecord
  STATUSES = %w[assigned submitted skipped expired].freeze

  belongs_to :user
  belongs_to :ship_event, class_name: "Post::ShipEvent", inverse_of: :vote_assignments
  belongs_to :vote, optional: true

  enum :status, {
    assigned: "assigned",
    submitted: "submitted",
    skipped: "skipped",
    expired: "expired"
  }, default: :assigned

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :ship_event_id }
  validate :ship_event_can_be_assigned, on: :create

  def self.current_for(user)
    assigned
      .joins(ship_event: :post)
      .where(user: user)
      .order(created_at: :desc)
      .first
  end

  def self.assign_to(user, user_agent: nil)
    matchmaker = Vote::Matchmaker.new(user, user_agent: user_agent)

    if current = current_for(user)
      current.refresh(matchmaker)
    else
      assign_new_to(user, matchmaker)
    end
  end

  def refresh(matchmaker = Vote::Matchmaker.new(user))
    if ship_event.certification_status == "rejected"
      replace_with(matchmaker.next_ship_event)
    # we don't have the countable scope... yet!
    elsif ship_event.payout.present? || ship_event.votes_count >= Post::ShipEvent::VOTES_TO_LEAVE_POOL
      if replacement = matchmaker.next_unpaid_ship_event
        replace_with(replacement)
      else
        self
      end
    else
      self
    end
  end

  def submit_vote(attributes)
    vote = build_vote(attributes.merge(user: user, ship_event: ship_event, project: ship_event.project))

    transaction do
      vote.save!
      update!(status: :submitted, vote: vote)
    end

    vote
  rescue ActiveRecord::RecordInvalid
    vote
  end

  def skip
    transaction do
      update!(status: :skipped)
      send_gorse_skip_later
    end
  end

  private
    def self.assign_new_to(user, matchmaker)
      if ship_event = matchmaker.next_ship_event
        create!(user: user, ship_event: ship_event)
      end
    end

    def replace_with(replacement_ship_event)
      transaction do
        update!(status: :expired)

        if replacement_ship_event
          self.class.create!(user: user, ship_event: replacement_ship_event)
        end
      end
    end

    def ship_event_can_be_assigned
      unless ship_event&.certification_status == "approved"
        errors.add(:ship_event, "must be approved")
      end
    end

    def send_gorse_skip_later
      if ship_event&.post.present?
        send_gorse_feedback_later(user: user, item: ship_event.post, feedback_type: :skip)
      end
    end
end
