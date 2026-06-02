module Raffle
  module Referrals
    # Opens a pending referral for a brand-new platform user whose signup
    # carried a raffle code (the platform already persisted it on `users.ref`).
    # Refs that aren't raffle codes — or codes with no matching participant —
    # are ignored, so this never interferes with other uses of `users.ref`.
    class Register
      def self.run_safely(user)
        new(user).run
      rescue StandardError => e
        Rails.logger.error("[Raffle::Referrals::Register] #{e.class}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
        nil
      end

      def initialize(user)
        @user = user
      end

      def run
        return if @user.ref.blank?

        match = /\A([rd])-([a-z0-9]{5})\z/.match(@user.ref.strip.downcase)
        return unless match

        participant = Raffle::Participant.find_by(code: match[2])
        return unless participant

        referral = Raffle::Referral.create_or_find_by!(referred_user_id: @user.id) do |r|
          r.participant = participant
          r.channel = match[1] == "d" ? "discord" : "web"
          r.raw_ref = match[0]
          r.status = :pending
        end

        # Rare, but a user can be created already-verified; credit immediately.
        Raffle::Referrals::Credit.run_safely(@user) if @user.identity_verified?

        referral
      end
    end
  end
end
