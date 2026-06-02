module Raffle
  # Mixed into the platform's User. Observes two lifecycle moments for the
  # referral program and delegates to engine services. Both are wrapped so a
  # raffle-side failure can never break platform login or verification.
  module ReferralTrackable
    extend ActiveSupport::Concern

    included do
      # New signup: if it carried a raffle code, open a pending referral.
      after_create_commit :register_raffle_referral
      # ID verification cleared: convert the pending referral and credit tickets.
      after_commit :credit_raffle_referral, if: :saved_change_to_verification_status?
    end

    private

    def register_raffle_referral
      Raffle::Referrals::Register.run_safely(self)
    end

    def credit_raffle_referral
      Raffle::Referrals::Credit.run_safely(self)
    end
  end
end
