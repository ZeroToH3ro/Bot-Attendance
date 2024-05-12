# frozen_string_literal: true
require_relative 'bot_message'
require 'gemoji'

module BotMessage
  BOT_START_MESSAGE = "Author Zero\nThanks for using BotZero!\n🤖 Nhấn nút attend để tiếp tục và thực hiện theo hướng dẫn."
  BOT_ACTION_MESSAGE = '🤖 Xin nhấn nút Attend để kết thúc điểm danh.'
  BOT_ERROR_MESSAGE = '🤖 Xin hãy bật dịch vụ Location trên máy bạn và nhấn nút Share location.'
  BOT_HELP_MESSAGE = "ℹ️ Sử dụng nút Attend để bắt đầu #{Emoji.find_by_alias('point_down').raw}\nKết quả sẽ dựa vào vị trí thực của bạn\nNếu bạn có thắc mắc hay góp ý hãy gửi về email mtblaser2002@gmail.com.\n"
  BOT_EXPORT_MESSAGE = "📥 Lưu ý: CSV FILE sẽ được gửi đến máy bạn nếu bạn là giảng viên"

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
