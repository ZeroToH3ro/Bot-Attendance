# frozen_string_literal: true
require_relative 'data/location'
require 'geocoder'
require 'dotenv'
require 'pg'
require 'csv'

Dotenv.load

class LocationAttendance
  TIME_STAMP = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  NOW_DATE = Time.now.strftime('%Y-%m-%d')
  LATITUDE_SCHOOL = ENV['LATITUDE_SCHOOL'].to_f
  LONGITUDE_SCHOOL = ENV['LONGITUDE_SCHOOL'].to_f
  CSV_FILE_PATH = "source/attendance_#{NOW_DATE}.csv"
  PROFESSOR_NAME = ENV['PROFESSOR_NAME']
  DB_HOST = ENV['DB_HOST']
  DB_NAME = ENV['DB_NAME']
  DB_USER = ENV['DB_USER']
  DB_PASSWORD = ENV['DB_PASSWORD']
  DB_PORT = ENV['DB_PORT']
  THRESHOLD_DISTANCE = ENV['THRESHOLD_DISTANCE'].to_i

  @@logger = Logger.new($stdout)
  @@logger.level = Logger::INFO

  def initialize; end

  def attend_location(bot, location, message)
    school_coordinates = [LATITUDE_SCHOOL, LONGITUDE_SCHOOL]
    puts "Coordinate of school and your location: #{school_coordinates.to_a} - #{location.to_a}"
    distance = Geocoder::Calculations.distance_between(school_coordinates, location.to_a)
    threshold_distance = THRESHOLD_DISTANCE

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
      bot.api.send_message(chat_id: message.from.id, text: "You are so far from me with your distance #{distance} miles. Or you are checked ")
      add_student(
        message.from.first_name,
        message.from.last_name,
        message.from.username,
        TIME_STAMP,
        false,
        message.from.id,
        location.to_a[0].to_f,
        location.to_a[1].to_f
      )
    end
    location.to_a
  end

  def export_csv(bot, message)
    conn = PG.connect(dbname: DB_NAME.to_s, user: DB_USER.to_s, password: DB_PASSWORD.to_s,
                      host: DB_HOST.to_s, port: DB_PORT.to_s)
    start_time = (DateTime.parse(TIME_STAMP) - Rational(15, 24 * 60)).strftime('%Y-%m-%d %H:%M:%S')
    end_time = (DateTime.parse(TIME_STAMP) + Rational(15, 24 * 60)).strftime('%Y-%m-%d %H:%M:%S')
    result = conn.exec_params('SELECT *, CASE WHEN attend THEN \'Yes\' ELSE \'No\' END AS attendance_status FROM students WHERE time BETWEEN $1::timestamp - interval \'15 minutes\' AND $2::timestamp + interval \'15 minutes\'', [start_time, end_time])

    unless File.exist?(CSV_FILE_PATH)
      CSV.open(CSV_FILE_PATH, 'wb') do |csv|
        csv << result.fields.reject { |field| field == 'attend' }.map { |field| field.split('_').map(&:capitalize).join(' ') }
      end
    end

    CSV.open(CSV_FILE_PATH, 'a') do |csv|
      result.each do |row|
        csv << row.reject { |key, _value| key == 'attend' }.values
      end
    end

    if message.from.username == PROFESSOR_NAME
      bot.api.send_document(chat_id: message.chat.id, document: Faraday::UploadIO.new(CSV_FILE_PATH, 'text/csv'))
      conn.close
      File.delete(CSV_FILE_PATH)
    else
      bot.api.send_message(chat_id: message.chat.id, text: "You are not professor. So I can not send CSV FILE to you")
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
    conn.close
  end

  def handle_user_spam?(bot, message)
    conn = PG.connect(dbname: DB_NAME.to_s, user: DB_USER.to_s, password: DB_PASSWORD.to_s, host: DB_HOST.to_s, port: DB_PORT.to_s)
    result = conn.exec('SELECT * FROM students WHERE user_id = $1 and time > now() - interval \'1 day\'', [message.from.id])

    if result.ntuples > 0
      false
    else
      true
    end
  end
end
