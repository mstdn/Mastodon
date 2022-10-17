# frozen_string_literal: true

class REST::TranslationSerializer < ActiveModel::Serializer
  attributes :content, :detected_source_language

  def content
    object.text
  end
end
