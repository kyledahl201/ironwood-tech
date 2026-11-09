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

  def page_title(title = nil)
    content_for(:title, title) if title
    [ content_for(:title).presence, brand.name ].compact.join(" · ")
  end

  def nav_link(label, path)
    tag.li { link_to label, path, aria: { current: (current_page?(path) ? "page" : nil) } }
  end

  # "Prof. Tomas Reyes, an AI tutor" or, for an unnamed persona, "an AI tutor".
  def tutor_label(course)
    name = course.tutor_name.to_s
    name.start_with?("Prof.") ? "#{name}, an AI tutor" : "an AI tutor"
  end

  def money(cents)
    format("$%.2f", cents.to_i / 100.0)
  end
end
