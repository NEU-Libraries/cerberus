# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

require 'csv'

# Path to the CSV file
csv_file_path = Rails.root.join('db', 'seeds', 'groups.csv')

# Parse the CSV and create Group objects
# Using pipe (|) as the column separator
CSV.foreach(csv_file_path, headers: true, col_sep: '|') do |row|
  # Create a new Group with the raw and cosmetic values
  group = Group.create!(
    raw: row['raw'],
    cosmetic: row['cosmetic']
  )

  puts "Created Group: #{group.cosmetic} (#{group.raw})"
end

puts "\nFinished importing #{Group.count} groups."
