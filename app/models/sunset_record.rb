class SunsetRecord < ApplicationRecord
  validates :city, :latitude, :longitude, :date, presence: true
  validates :date, uniqueness: { scope: [:latitude, :longitude] }
end
