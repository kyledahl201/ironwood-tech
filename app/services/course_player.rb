# A course that ships as one self-contained player page instead of rows in the
# lesson tables (db/course_players/<course slug>/). The folder is outside
# public/, so the page is only ever sent by CoursePlayersController after it
# has checked the student's enrollment.
#
#   index.html    the built player (a page fragment: title, styles, markup, script)
#   downloads/    optional practice files, handed over as one .zip
class CoursePlayer
  ROOT = Rails.root.join("db/course_players")

  attr_reader :slug

  def self.for(course)
    slug = course.slug.to_s
    return nil unless slug.match?(/\A[a-z0-9-]+\z/)
    player = new(slug)
    player if player.exist?
  end

  def initialize(slug)
    @slug = slug
  end

  def dir = ROOT.join(slug)
  def exist? = dir.join("index.html").file?

  # The build is a fragment, so wrap it in a document (as its own build script
  # does for the copy that opens from a folder).
  def html(back_url: nil, back_label: nil)
    back = back_url ? %(<p style="text-align:center;padding:24px 16px"><a href="#{ERB::Util.html_escape(back_url)}">#{ERB::Util.html_escape(back_label)}</a></p>\n) : ""
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <meta name="robots" content="noindex, nofollow">
      </head>
      <body>
      #{dir.join("index.html").read}
      #{back}</body>
      </html>
    HTML
  end

  def download_files
    base = dir.join("downloads")
    Dir[base.join("**/*")].select { |path| File.file?(path) }.sort.map { |path| [ Pathname(path).relative_path_from(base).to_s, path ] }
  end

  def downloads? = download_files.any?
  def download_folder = "ironwood-#{slug}-practice-files"
  def download_filename = "#{download_folder}.zip"
  def download_zip = ZipWriter.build(download_files.map { |name, path| [ "#{download_folder}/#{name}", File.binread(path) ] })
end
