# frozen_string_literal: true

require 'singleton'

class HTMLRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    "<pre><code>#{encode(code).gsub("\n", "<br/>")}</code></pre>"
  end

  def autolink(link, link_type)
    return link if link_type == :email
    Formatter.instance.link_url(link)
  rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
    encode(link)
  end

  private

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end
end

class Formatter
  include Singleton
  include RoutingHelper

  include ActionView::Helpers::TextHelper

  def format(status, **options)
    if status.respond_to?(:reblog?) && status.reblog?
      prepend_reblog = status.reblog.account.acct
      status         = status.proper
    else
      prepend_reblog = false
    end

    raw_content = status.text

    if options[:inline_poll_options] && status.preloadable_poll
      raw_content = raw_content + "\n\n" + status.preloadable_poll.options.map { |title| "[ ] #{title}" }.join("\n")
    end

    return '' if raw_content.blank?

    unless status.local?
      html = reformat(raw_content)
      html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]
      return html.html_safe # rubocop:disable Rails/OutputSafety
    end

    linkable_accounts = status.respond_to?(:active_mentions) ? status.active_mentions.map(&:account) : []
    linkable_accounts << status.account

    html = raw_content
    html = "RT @#{prepend_reblog} #{html}" if prepend_reblog
    html = format_markdown(html) if status.content_type == 'text/markdown'
    html = encode_and_link_urls(html, linkable_accounts, keep_html: %w(text/markdown text/html).include?(status.content_type))
    html = reformat(html, true) if %w(text/markdown text/html).include?(status.content_type)
    html = encode_custom_emojis(html, status.emojis, options[:autoplay]) if options[:custom_emojify]

    unless %w(text/markdown text/html).include?(status.content_type)
      html = simple_format(html, {}, sanitize: false)
      html = html.delete("\n")
    end

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_markdown(html)
    html = markdown_formatter.render(html)
    html.delete("\r").delete("\n")
  end

  def reformat(html, outgoing = false)
    sanitize(html, Sanitize::Config::MASTODON_STRICT.merge(outgoing: outgoing))
  rescue ArgumentError
    ''
  end

  def plaintext(status)
    return status.text if status.local?

    text = status.text.gsub(/(<br \/>|<br>|<\/p>)+/) { |match| "#{match}\n" }
    strip_tags(text)
  end

  def simplified_format(account, **options)
    return '' if account.note.blank?

    html = account.local? ? linkify(account.note) : reformat(account.note)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def sanitize(html, config)
    Sanitize.fragment(html, config)
  end

  def format_spoiler(status, **options)
    html = encode(status.spoiler_text)
    html = encode_custom_emojis(html, status.emojis, options[:autoplay])
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_poll_option(status, option, **options)
    html = encode(option.title)
    html = encode_custom_emojis(html, status.emojis, options[:autoplay])
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_display_name(account, **options)
    html = encode(account.display_name.presence || account.username)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def format_field(account, str, **options)
    html = account.local? ? encode_and_link_urls(str, me: true, with_domain: true) : reformat(str)
    html = encode_custom_emojis(html, account.emojis, options[:autoplay]) if options[:custom_emojify]
    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def linkify(text)
    html = encode_and_link_urls(text)
    html = simple_format(html, {}, sanitize: false)
    html = html.delete("\n")

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def link_url(url)
    "<a href=\"#{encode(url)}\" target=\"blank\" rel=\"nofollow noopener noreferrer\">#{link_html(url)}</a>"
  end

  private

  def markdown_formatter
    extensions = {
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      footnotes: false,
    }

    renderer = HTMLRenderer.new({
      filter_html: false,
      escape_html: false,
      no_images: true,
      no_styles: true,
      safe_links_only: true,
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'nofollow noopener' },
    })

    Redcarpet::Markdown.new(renderer, extensions)
  end

  def html_entities
    @html_entities ||= HTMLEntities.new
  end

  def encode(html)
    html_entities.encode(html)
  end

  def encode_and_link_urls(html, accounts = nil, options = {})
    if accounts.is_a?(Hash)
      options  = accounts
      accounts = nil
    end

    entities = options[:keep_html] ? html_friendly_extractor(html) : utf8_friendly_extractor(html, extract_url_without_protocol: false)

    rewrite(html.dup, entities, options[:keep_html]) do |entity|
      if entity[:url]
        link_to_url(entity, options)
      elsif entity[:hashtag]
        link_to_hashtag(entity)
      elsif entity[:screen_name]
        link_to_mention(entity, accounts, options)
      end
    end
  end

  def count_tag_nesting(tag)
    if tag[1] == '/' then -1
    elsif tag[-2] == '/' then 0
    else 1
    end
  end

  # rubocop:disable Metrics/BlockNesting
  def encode_custom_emojis(html, emojis, animate = false)
    return html if emojis.empty?

    emoji_map = emojis.each_with_object({}) { |e, h| h[e.shortcode] = [full_asset_url(e.image.url), full_asset_url(e.image.url(:static))] }

    i                     = -1
    tag_open_index        = nil
    inside_shortname      = false
    shortname_start_index = -1
    invisible_depth       = 0

    while i + 1 < html.size
      i += 1

      if invisible_depth.zero? && inside_shortname && html[i] == ':'
        shortcode = html[shortname_start_index + 1..i - 1]
        emoji     = emoji_map[shortcode]

        if emoji
          original_url, static_url = emoji
          replacement = begin
            if animate
              image_tag(original_url, draggable: false, class: 'emojione', alt: ":#{shortcode}:", title: ":#{shortcode}:")
            else
              image_tag(original_url, draggable: false, class: 'emojione custom-emoji', alt: ":#{shortcode}:", title: ":#{shortcode}:", data: { original: original_url, static: static_url })
            end
          end
          before_html = shortname_start_index.positive? ? html[0..shortname_start_index - 1] : ''
          html        = before_html + replacement + html[i + 1..-1]
          i          += replacement.size - (shortcode.size + 2) - 1
        else
          i -= 1
        end

        inside_shortname = false
      elsif tag_open_index && html[i] == '>'
        tag = html[tag_open_index..i]
        tag_open_index = nil
        if invisible_depth.positive?
          invisible_depth += count_tag_nesting(tag)
        elsif tag == '<span class="invisible">'
          invisible_depth = 1
        end
      elsif html[i] == '<'
        tag_open_index   = i
        inside_shortname = false
      elsif !tag_open_index && html[i] == ':'
        inside_shortname      = true
        shortname_start_index = i
      end
    end

    html
  end
  # rubocop:enable Metrics/BlockNesting

  def rewrite(text, entities, keep_html = false)
    text = text.to_s

    # Sort by start index
    entities = entities.sort_by do |entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      indices.first
    end

    result = []

    last_index = entities.reduce(0) do |index, entity|
      indices = entity.respond_to?(:indices) ? entity.indices : entity[:indices]
      result << (keep_html ? text[index...indices.first] : encode(text[index...indices.first]))
      result << yield(entity)
      indices.last
    end

    result << (keep_html ? text[last_index..-1] : encode(text[last_index..-1]))

    result.flatten.join
  end

  def utf8_friendly_extractor(text, options = {})
    # Note: I couldn't obtain list_slug with @user/list-name format
    # for mention so this requires additional check
    special = Extractor.extract_urls_with_indices(text, options)
    standard = Extractor.extract_entities_with_indices(text, options)
    extra = Extractor.extract_extra_uris_with_indices(text, options)

    Extractor.remove_overlapping_entities(special + standard + extra)
  end

  def html_friendly_extractor(html, options = {})
    gaps = []
    total_offset = 0

    escaped = html.gsub(/<[^>]*>|&#[0-9]+;/) do |match|
      total_offset += match.length - 1
      end_offset = Regexp.last_match.end(0)
      gaps << [end_offset - total_offset, total_offset]
      "\u200b"
    end

    entities = Extractor.extract_hashtags_with_indices(escaped, :check_url_overlap => false) +
               Extractor.extract_mentions_or_lists_with_indices(escaped)
    Extractor.remove_overlapping_entities(entities).map do |extract|
      pos = extract[:indices].first
      offset_idx = gaps.rindex { |gap| gap.first <= pos }
      offset = offset_idx.nil? ? 0 : gaps[offset_idx].last
      next extract.merge(
        :indices => [extract[:indices].first + offset, extract[:indices].last + offset]
      )
    end
  end

  def link_to_url(entity, options = {})
    url        = Addressable::URI.parse(entity[:url])
    html_attrs = { target: '_blank', rel: 'nofollow noopener noreferrer' }

    html_attrs[:rel] = "me #{html_attrs[:rel]}" if options[:me]

    Twitter::TwitterText::Autolink.send(:link_to_text, entity, link_html(entity[:url]), url, html_attrs)
  rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
    encode(entity[:url])
  end

  def link_to_mention(entity, linkable_accounts, options = {})
    acct = entity[:screen_name]

    return link_to_account(acct, options) unless linkable_accounts

    same_username_hits = 0
    account = nil
    username, domain = acct.split('@')
    domain = nil if TagManager.instance.local_domain?(domain)

    linkable_accounts.each do |item|
      same_username = item.username.casecmp(username).zero?
      same_domain   = item.domain.nil? ? domain.nil? : item.domain.casecmp(domain)&.zero?

      if same_username && !same_domain
        same_username_hits += 1
      elsif same_username && same_domain
        account = item
      end
    end

    account ? mention_html(account, with_domain: same_username_hits.positive? || options[:with_domain]) : "@#{encode(acct)}"
  end

  def link_to_account(acct, options = {})
    username, domain = acct.split('@')

    domain  = nil if TagManager.instance.local_domain?(domain)
    account = EntityCache.instance.mention(username, domain)

    account ? mention_html(account, with_domain: options[:with_domain]) : "@#{encode(acct)}"
  end

  def link_to_hashtag(entity)
    hashtag_html(entity[:hashtag])
  end

  def link_html(url)
    url    = Addressable::URI.parse(url).to_s
    prefix = url.match(/\A(https?:\/\/(www\.)?|xmpp:)/).to_s
    text   = url[prefix.length, 30]
    suffix = url[prefix.length + 30..-1]
    cutoff = url[prefix.length..-1].length > 30

    "<span class=\"invisible\">#{encode(prefix)}</span><span class=\"#{cutoff ? 'ellipsis' : ''}\">#{encode(text)}</span><span class=\"invisible\">#{encode(suffix)}</span>"
  end

  def hashtag_html(tag)
    "<a href=\"#{encode(tag_url(tag))}\" class=\"mention hashtag\" rel=\"tag\">#<span>#{encode(tag)}</span></a>"
  end

  def mention_html(account, with_domain: false)
    "<span class=\"h-card\"><a href=\"#{encode(ActivityPub::TagManager.instance.url_for(account))}\" class=\"u-url mention\">@<span>#{encode(with_domain ? account.pretty_acct : account.username)}</span></a></span>"
  end
end
