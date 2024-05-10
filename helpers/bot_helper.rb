# frozen_string_literal: true
require 'gemoji'
require_relative '../data/location'
require_relative '../location_attendance'

module BotHelper
  def self.bot_markup
    kb = [[Telegram::Bot::Types::KeyboardButton.new(text: 'Start'),
           Telegram::Bot::Types::KeyboardButton.new(text: 'Help')],
          [Telegram::Bot::Types::KeyboardButton.new(text: 'Share location', request_location: true),
        ]
    ]
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb, resize_keyboard: true)
  end

  def self.export_csv(bot, message)
    LocationAttendance.new.export_csv(bot, message)
  end

  def self.get_location_inline(coordinate, data, action = 'a')
    if %w[attend
          drop].include? data.query&.downcase
      get_location(coordinate, data.query&.downcase&.include?('drop') ? 'd' : 'a')
    end
  end

  def self.inline_markup(location = nil)
    kb = location.nil? ? chat_inline_location_markup : shared_inline_location_markup(location)
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end

  def self.inline_result(location)
    result = []
    if arr = Array.try_convert(location)
      puts "Convert array pass #{arr}"
      result = arr.map { |element| create_inline_attend_result(element) }
    else
      result << create_inline_attend_result(location)
    end
    result
  end

  def self.create_inline_attend_result(location)
    Telegram::Bot::Types::InlineQueryResultLocation.new(
      id: location.latitude.to_s + location.longitude.to_s,
      latitude: location.latitude,
      longitude: location.longitude,
      title: location.action == 'a' ? 'Attend' : 'Drop',
      live_period: 60
      )
  end

  def self.get_location(bot, data_location, data, action = 'a')
    begin
      LocationAttendance.new.attend_location(bot, Location.new(data_location, action), data)
    rescue StandardError
      []
    end
  end

  def self.shared_inline_location_markup(location)
    [[
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Attend',
                                                    callback_data: Location.new(location).to_callback_loc)
    ]]
  end

  def self.chat_inline_location_markup
    [[
      Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Attend', switch_inline_query_current_chat: 'attend'),
    ]]
  end
end
