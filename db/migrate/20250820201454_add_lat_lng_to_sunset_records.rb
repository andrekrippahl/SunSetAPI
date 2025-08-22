class AddLatLngToSunsetRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :sunset_records, :city, :string
    add_column :sunset_records, :latitude, :float
    add_column :sunset_records, :longitude, :float
  end
end
