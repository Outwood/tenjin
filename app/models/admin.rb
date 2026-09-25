# frozen_string_literal: true

class Admin < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable,
    :recoverable, :rememberable, :validatable, :lockable,
    authentication_keys: [:email],
    # NIST SP 800-63B-4 minimum for a password that is the only factor
    password_length: 15..128,
    lock_strategy: :failed_attempts, maximum_attempts: 5,
    unlock_strategy: :both, unlock_in: 1.hour

  validates :role, presence: true

  enum :role, {super: 0, school_group: 1}
end
