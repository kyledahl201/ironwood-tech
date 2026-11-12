# A tutor kit: Markdown files the faculty wrote for one course
# (db/tutor_kits/<course>/*.md). A student downloads them as one .zip and adds
# them to their own Claude project, so the course's professor can coach them
# there. The kit holds a persona, rules, the syllabus and rubrics. It never
# holds solutions: the student can read every file in it.
class TutorKit
  ROOT = Rails.root.join("db/tutor_kits")

  attr_reader :course_code, :slug

  def self.for(course_code)
    slug = course_code.to_s.parameterize
    kit = new(course_code, slug)
    kit if slug.present? && kit.files.any?
  end

  def self.find(slug) = all.find { |kit| kit.slug == slug }

  def self.all
    ClassLesson.distinct.pluck(:course_code).filter_map { |code| self.for(code) }
  end

  def initialize(course_code, slug)
    @course_code = course_code
    @slug = slug
  end

  # README first, then the rest by name.
  def files
    @files ||= Dir[ROOT.join(slug, "*.md")].sort_by { |path| [ File.basename(path) == "README.md" ? 0 : 1, File.basename(path) ] }
  end

  def names = files.map { |path| File.basename(path) }
  def folder = "ironwood-#{slug}-tutor-kit"
  def filename = "#{folder}.zip"
  def zip = ZipWriter.build(files.map { |path| [ "#{folder}/#{File.basename(path)}", File.read(path) ] })
end
