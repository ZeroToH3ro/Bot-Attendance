# frozen_string_literal: true
require_relative 'data/location'
require 'geocoder'
require 'dotenv'
require 'pg'
require 'csv'
require "active_support/all"

Dotenv.load

class LocationAttendance
  # Set timezone = 'Asia/Bangkok'
  Time.zone = 'Asia/Bangkok'
  NOW_DATE = Time.zone.now.strftime('%Y-%m-%d')
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
  TIME_TO_CHECK = ENV['TIME_TO_CHECK'].to_i

  @@logger = Logger.new($stdout)
  @@logger.level = Logger::INFO

  def initialize; end

  def attend_location(bot, location, message)
    time_now = Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')
    school_coordinates = [LATITUDE_SCHOOL, LONGITUDE_SCHOOL]
    puts "Coordinate of school and your location: #{school_coordinates.to_a} - #{location.to_a}"
    distance = Geocoder::Calculations.distance_between(school_coordinates, location.to_a)
    formatted_distance = format("%.2f", distance)
    threshold_distance = THRESHOLD_DISTANCE
    puts "Timestamp: #{time_now}"
    if handle_user_spam?(bot, message)
      puts 'User attempt check in too fast'
      bot.api.send_message(chat_id: message.from.id, text: "Bạn đã điểm danh, vui lòng điểm danh sau #{TIME_TO_CHECK} phút nữa.")
      return location.to_a
    end

    if distance <= threshold_distance
      begin
        puts "Your location => Latitude: #{location.to_a[0].to_f} - Longitude: #{location.to_a[1].to_f} - Distance: #{formatted_distance}"
        add_student(
          message.from.first_name,
          message.from.last_name,
          message.from.username,
          time_now,
          true,
          message.from.id,
          location.to_a[0].to_f,
          location.to_a[1].to_f
        )
        bot.api.send_message(chat_id: message.from.id, text: "Bạn đã điểm danh thành công vào lúc #{time_now}")
        puts 'You are checked => Add Student Successfully'
      rescue StandardError => e
        puts "Error: #{e}\nStack trace: #{e.backtrace.join("\n\t")}"
      end
    else
      bot.api.send_message(chat_id: message.from.id, text: "Vị trí của bạn cách xa vị trí điểm danh khoảng #{formatted_distance} miles - #{time_now} ")
      add_student(
        message.from.first_name,
        message.from.last_name,
        message.from.username,
        time_now,
        false,
        message.from.id,
        location.to_a[0].to_f,
        location.to_a[1].to_f
      )
    end
    location.to_a
  end

  def export_csv(bot, message)
    time_now = Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')
    conn = PG.connect(dbname: DB_NAME.to_s, user: DB_USER.to_s, password: DB_PASSWORD.to_s,
                      host: DB_HOST.to_s, port: DB_PORT.to_s)
    start_time = (DateTime.parse(time_now) - Rational(30, 24 * 60)).strftime('%Y-%m-%d %H:%M:%S')
    end_time = (DateTime.parse(time_now) + Rational(30, 24 * 60)).strftime('%Y-%m-%d %H:%M:%S')
    result = conn.exec_params('SELECT *, CASE WHEN attend THEN \'Yes\' ELSE \'No\' END AS attendance_status FROM students WHERE time BETWEEN $1::timestamp - interval \'15 minutes\' AND $2::timestamp + interval \'15 minutes\'', [start_time, end_time])

    unless File.exist?(CSV_FILE_PATH)
      CSV.open(CSV_FILE_PATH, 'wb', encoding: 'UTF-8') do |csv|
        csv << result.fields.reject { |field| field == 'attend' }.map { |field| field.split('_').map(&:capitalize).join(' ') }
      end
    end

    CSV.open(CSV_FILE_PATH, 'a', encoding: 'UTF-8') do |csv|
      result.each do |row|
        csv << row.reject { |key, _value| key == 'attend' }.values
      end
    end

    user_name = message.from.username
    professor_names = PROFESSOR_NAME.split(',')

    if professor_names.any? { |professor_name| professor_name == user_name }
      bot.api.send_document(chat_id: message.chat.id, document: Faraday::UploadIO.new(CSV_FILE_PATH, 'text/csv'))
      File.delete(CSV_FILE_PATH)
      conn.close
    else
      bot.api.send_message(chat_id: message.chat.id, text: "Bạn không phải giáo sư. Nên tôi không thể gửi file csv cho bạn được.")
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
    begin
      time_now = Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')
      conn = PG.connect(dbname: DB_NAME.to_s, user: DB_USER.to_s, password: DB_PASSWORD.to_s, host: DB_HOST.to_s, port: DB_PORT.to_s)
      result = conn.exec_params('SELECT * FROM students WHERE user_id = $1 ORDER BY time DESC LIMIT 1', [message.from.id])
      current_time = Time.parse(time_now)
      puts "current_time: #{current_time} - result: #{result}"
      if result.ntuples > 0
        puts "You already checked in. #{current_time} - #{result[0]['time']}"
        last_interaction_time = Time.zone.parse(result[0]['time'])
        puts "last_interaction_time: #{last_interaction_time}"
        puts "time_to_check: #{ current_time - last_interaction_time }"
        if (current_time - last_interaction_time) < 60 * TIME_TO_CHECK
          puts 'User attempt check in too fast'
          return true
        end
      end
      puts "User is allowed to check in."
      return false
    rescue PG::Error => e
      puts "Error executing SQL query: #{e.message}"
      return true # Allow the user to proceed in case of an error
    ensure
      conn.close if conn
    end
  end
end
