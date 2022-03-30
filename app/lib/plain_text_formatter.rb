# frozen_string_literal: true

class PlainTextFormatter
  include ActionView::Helpers::TextHelper

  NEWLINE_TAGS_RE = /(<br \/>|<br>|<\/p>)+/.freeze

  attr_reader :text, :local

  alias local? local

  def initialize(text, local)
    @text  = text
    @local = local
  end

  def to_s
    if local?
      text
    else
      strip_tags(insert_newlines).chomp
    end
  end

  private

  def insert_newlines
    text.gsub(NEWLINE_TAGS_RE) { |match| "#{match}\n" }
  end
end
