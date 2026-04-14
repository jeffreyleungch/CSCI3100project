class User < ApplicationRecord
  ROLES = %w[student moderator admin].freeze

  belongs_to :community
  has_many :bids, dependent: :nullify
  has_many :payment_records, dependent: :nullify
  has_many :items, dependent: :nullify

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :password_digest, presence: true

  def password=(raw_password)
    @raw_password = raw_password
    self.password_digest = BCrypt::Password.create(raw_password) if raw_password.to_s != ''
  end

  def password
    @raw_password
  end

  def authenticate(raw_password)
    return false if password_digest.to_s == '' || raw_password.to_s == ''

    BCrypt::Password.new(password_digest).is_password?(raw_password) ? self : false
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def moderator?
    role == 'moderator' || admin?
  end

  def admin?
    role == 'admin'
  end
end
