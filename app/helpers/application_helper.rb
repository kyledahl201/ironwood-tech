module ApplicationHelper
  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: true, safe_links_only: true, no_styles: true, hard_wrap: false,
                                link_attributes: { rel: "nofollow noopener" }),
    fenced_code_blocks: true, tables: true, autolink: true, strikethrough: true, no_intra_emphasis: true
  )

  # Markdown with raw HTML stripped, so tutor replies and stored content can't inject markup.
  def markdown(text)
    sanitize(MARKDOWN.render(text.to_s))
  end

  # One line of Markdown (code spans, emphasis) without a wrapping paragraph.
  def markdown_inline(text)
    markdown(text).sub(%r{\A<p>}, "").sub(%r{</p>\s*\z}, "").html_safe
  end

  def page_title(title = nil)
    content_for(:title, title) if title
    [ content_for(:title).presence, brand.name ].compact.join(" · ")
  end

  def nav_link(label, path)
    tag.li { link_to label, path, aria: { current: (current_page?(path) ? "page" : nil) } }
  end

  def badge_file(key)
    Rails.root.join("app/assets/images/badges/#{key}.svg").exist? ? "badges/#{key}.svg" : "brand/crest-v5-badge.svg"
  end

  def badge_image(key, size: 64, earned: true)
    image_tag badge_file(key), alt: Badges::ALL[key]&.name.to_s, width: size, height: (size * 1.12).round, class: "badge-img#{' is-locked' unless earned}"
  end

  # "Prof. Tomas Reyes, an AI tutor" or, for an unnamed persona, "an AI tutor".
  def tutor_label(course)
    name = course.tutor_name.to_s
    name.start_with?("Prof.") ? "#{name}, an AI tutor" : "an AI tutor"
  end
end
