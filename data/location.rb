# frozen_string_literal: true

class Location
  attr_accessor :latitude, :longitude, :action

  def initialize(element, action = 'a')
    case element
    when String
      loc = eval(element)
      self.latitude = loc[:latitude]
      self.longitude = loc[:longitude]
      self.action = loc[:a]
    when Telegram::Bot::Types::Location
      self.latitude = element.latitude
      self.longitude = element.longitude
      self.action = action
    end
  end

  def to_s
    %("Latitude: #{latitude} Longitude: #{longitude}")
  end

  def to_a
    [latitude, longitude]
  end

  def to_callback_loc
    { latitude: latitude, longitude: longitude, a: action }.to_s
  end
end
