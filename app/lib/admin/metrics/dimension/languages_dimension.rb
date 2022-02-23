# frozen_string_literal: true

class Admin::Metrics::Dimension::LanguagesDimension < Admin::Metrics::Dimension::BaseDimension
  include LanguagesHelper

  def key
    'languages'
  end

  protected

  def perform_query
    sql = <<-SQL.squish
      SELECT locale, count(*) AS value
      FROM users
      WHERE current_sign_in_at BETWEEN $1 AND $2
        AND locale IS NOT NULL
      GROUP BY locale
      ORDER BY count(*) DESC
      LIMIT $3
    SQL

    rows = ActiveRecord::Base.connection.select_all(sql, nil, [[nil, @start_at], [nil, @end_at], [nil, @limit]])

    rows.map { |row| { key: row['locale'], human_key: standard_locale_name(row['locale']), value: row['value'].to_s } }
  end
end
