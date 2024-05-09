# frozen_string_literal: true
require_relative 'data/location'
require 'geocoder'
require 'dotenv'
require 'pg'
require 'csv'

Dotenv.load

class LocationAttendance
  TIME_STAMP = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  LATITUDE_SCHOOL = ENV['LATITUDE_SCHOOL'].to_f
  LONGITUDE_SCHOOL = ENV['LONGITUDE_SCHOOL'].to_f
  CSV_FILE_PATH = "source/attendance_#{TIME_STAMP}.csv"
  CSV_HEADERS = ['ID', 'Last Name', 'First Name', 'Full Name', 'Timestamp', 'Attend', 'USER_ID', 'Latitude', 'Longitude'].freeze
  PROFESSOR_NAME = ENV['PROFESSOR_NAME']
  DB_HOST = ENV['DB_HOST']
  DB_NAME = ENV['DB_NAME']
  DB_USER = ENV['DB_USER']
  DB_PASSWORD = ENV['DB_PASSWORD']
  DB_PORT = ENV['DB_PORT']

  @@logger = Logger.new($stdout)
  @@logger.level = Logger::INFO

  def initialize; end

  def attend_location(bot, location, message)
    school_coordinates = [LATITUDE_SCHOOL, LONGITUDE_SCHOOL]
    puts "Coordinate of school and your location: #{school_coordinates.to_a} - #{location.to_a}"
    distance = Geocoder::Calculations.distance_between(school_coordinates, location.to_a)
    threshold_distance = 100

    if distance <= threshold_distance
      begin
        puts "Your location => Latitude: #{location.to_a[0].to_f} - Longitude: #{location.to_a[1].to_f} - Distance: #{distance}"
        add_student(
          message.from.first_name,
          message.from.last_name,
          message.from.username,
          TIME_STAMP,
          true,
          message.from.id,
          location.to_a[0].to_f,
          location.to_a[1].to_f
        )
        bot.api.send_message(chat_id: message.from.id, text: "You are checked in #{TIME_STAMP}")
        puts 'You are checked => Add Student Successfully'
      rescue StandardError => e
        puts "Error: #{e}\nStack trace: #{e.backtrace.join("\n\t")}"
      end
    else
      puts "You are so far from me with your distance #{distance} m."
    end
    location.to_a
  end

  def export_csv(bot, message)
    unless File.exist?(CSV_FILE_PATH)
      CSV.open(CSV_FILE_PATH, 'w') do |csv|
        csv << CSV_HEADERS
      end
    end

    conn = PG.connect(dbname: DB_NAME.to_s, user: DB_USER.to_s, password: DB_PASSWORD.to_s, host: DB_HOST.to_s, port: DB_PORT.to_s)
    result = conn.exec('SELECT * FROM students WHERE time > now() - interval \'1 day\'')
    rows = result.map(&:values)

    CSV.open(CSV_FILE_PATH, 'a') do |csv|
      rows.each { |row| csv << row }
    end

    if message.from.username == PROFESSOR_NAME
      bot.api.send_document(chat_id: message.chat.id, document: Faraday::UploadIO.new(CSV_FILE_PATH, 'text/csv'))
    end
  end

  def add_student(first_name, last_name, username, time, attend, user_id, latitude, longitude)
    sql = <<~SQL
      INSERT INTO students (first_name, last_name, username, time, attend, user_id, latitude, longitude)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    SQL

    conn = PG.connect(dbname: DB_NAME.to_s, user: DB_USER.to_s, password: DB_PASSWORD.to_s, host: DB_HOST.to_s, port: DB_PORT.to_s)
    conn.exec_params(sql, [
      first_name,
      last_name,
      username,
      time,
      attend,
      user_id,
      latitude,
      longitude
    ])
  end

end
