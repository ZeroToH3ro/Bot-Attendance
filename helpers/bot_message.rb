# frozen_string_literal: true
require_relative 'bot_message'
require 'gemoji'

module BotMessage
  BOT_START_MESSAGE = "Author Zero\nThanks for using BotZero!\n🤖 Would you like to..."
  BOT_ACTION_MESSAGE = '🤖 Would you like to...'
  BOT_ERROR_MESSAGE = '🤖 Please share your location to mark attendance.'
  BOT_HELP_MESSAGE = "ℹ️ Use inline buttons below #{Emoji.find_by_alias('point_down').raw} (PickUp or Drop) here or type the inline command @bikingram_bot in any chat to find out the closest sharing bike station.\nThe result will be according to your actual position.\nYou can also pin any location and this bot will show you the closest station from that point."
  BOT_EXPORT_MESSAGE = "CSV File has been sent to your phone."

  def self.send_bot_message(bot, chat_id, markup, text = nil)
    bot.api.send_message(chat_id: chat_id, text: (text.nil? ? BOT_START_MESSAGE : text).to_s, reply_markup: markup)
  end

  def self.send_location_message(bot, chat_id, location = nil, inline = false)
    inline ? send_inline_attend_location(bot, chat_id, location) : send_callback_station_location(bot, chat_id, location)
  end

  def self.send_callback_station_location(bot, chat_id, location)
    bot.api.send_venue(
      chat_id: chat_id,
      latitude: location[0],
      longitude: location[1],
      address: location.to_s
    )
  end

  def self.send_inline_attend_location(bot, chat_id, location)
    bot.api.answer_inline_query(
      inline_query_id: chat_id,
      results: BotHelper.inline_result(location)
    )
  end
end
