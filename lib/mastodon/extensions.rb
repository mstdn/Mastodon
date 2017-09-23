class Mastodon::Extension
  @@extensions = []

  def self.register url
    @extensions << Extension.new(url)
  end

  def self.all
    @extensions
  end

  def initialize url
    @url = url
  end

  attr_reader :url
end
