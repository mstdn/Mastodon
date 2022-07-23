# frozen_string_literal: true

class URLValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid) unless compliant?(value)
  end

  private

  def compliant?(url)
    parsed_url = Addressable::URI.parse(url)
    parsed_url && %w(http https).include?(parsed_url.scheme) && parsed_url.host
  end
end
