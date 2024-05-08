# frozen_string_literal: true
require 'telegram/bot'

require_relative 'helpers/bot_helper'
require_relative 'helpers/bot_message'
require 'dotenv'
Dotenv.load

TELEGRAM_BOT_TOKEN = ENV['TELEGRAM_BOT_TOKEN']

Telegram::Bot::Client.run(TELEGRAM_BOT_TOKEN) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::CallbackQuery
      puts "Callback is call #{message.data}"
      location = BotHelper.get_location(bot, message.data, message)
      BotMessage.send_location_message(bot, message.from.id, location)
    when Telegram::Bot::Types::InlineQuery
      location = BotHelper.get_location_inline(message.data, message)
      BotMessage.send_location_message(bot, message.from.id, location, true)
    when Telegram::Bot::Types::Message
      if message.venue&.location
        puts 'Send venue successfully'
        BotMessage.send_bot_message(bot, message.chat.id, BotHelper.inline_markup, BotMessage::BOT_ACTION_MESSAGE)
      elsif message.location
        puts 'Send location successfully'
        BotMessage.send_bot_message(bot, message.chat.id, BotHelper.inline_markup(message.location), BotMessage::BOT_ACTION_MESSAGE)
      end
      case message.text
      when 'Help'
        BotMessage.send_bot_message(bot, message.chat.id, BotHelper.inline_markup, BotMessage::BOT_HELP_MESSAGE)
      when 'Start'
        BotMessage.send_bot_message(bot, message.chat.id, BotHelper.inline_markup, BotMessage::BOT_START_MESSAGE)
      when '/export'
        BotMessage.send_bot_message(bot, message.chat.id, BotHelper.export_csv(bot, message), BotMessage::BOT_EXPORT_MESSAGE)
      when '/start'
        BotMessage.send_bot_message(bot, message.chat.id, BotHelper.inline_markup)
      else
        unless message.text.nil?
          BotMessage.send_bot_message(bot, message.chat.id, BotHelper.bot_markup, BotMessage::BOT_ERROR_MESSAGE)
        end
      end
    end
  end
end
