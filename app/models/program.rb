# What a buyer gets: a program of classes (courses) in one of three tiers.
# Owning a program (ProgramEnrollment: bought, given by the owner, or a claimed
# gift) opens every class in it, because it gives the owner an enrollment in
# each of its courses, and User#can_open? stays the one ownership rule.
#
# config/program_catalog.yml lists the tiers (with their public names) and the
# programs; Program.sync! makes them. A program with no classes yet is
# "Coming": it is listed, and can't be bought or given.
class Program < ApplicationRecord
  FILE = Rails.root.join("config/program_catalog.yml")

  Tier = Struct.new(:code, :name, :blurb, keyword_init: true)

  has_many :courses, -> { order(:position, :id) }, dependent: :nullify
  has_many :program_enrollments, dependent: :restrict_with_error
  has_many :gifts, dependent: :restrict_with_error

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :tier, inclusion: { in: ->(_) { Program.tiers.map(&:code) } }
  # Stripe's smallest card charge in US dollars is 50 cents.
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 50 }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }
  scope :listed, -> { where(published: true).ordered }

  def self.config = YAML.safe_load_file(FILE)

  # The three tiers, in order: internal code (PX1, PYX, PX2) and public name.
  def self.tiers
    @tiers ||= config.fetch("tiers").map { |t| Tier.new(code: t["code"], name: t["name"], blurb: t["blurb"]) }.freeze
  end

  def self.tier(code) = tiers.find { |t| t.code == code }

  # Makes the programs in config/program_catalog.yml and places their courses.
  # Run by db/seeds.rb on every start; safe to run again. A new program gets
  # the file's text; after that, the owner's edits (text, price, published)
  # are kept, and only the tier and the order follow the file. A course is
  # placed only while it has no program, so the owner's moves stick. Anyone
  # who owns a program then gets any class newly placed in it.
  def self.sync!
    config.fetch("programs").each_with_index do |row, i|
      program = find_or_initialize_by(slug: row.fetch("slug"))
      program.assign_attributes(title: row["title"], tagline: row["tagline"], description: row["description"]) if program.new_record?
      program.assign_attributes(tier: row.fetch("tier"), position: i)
      program.save!
      Array(row["classes"]).each do |key|
        Course.where(program_id: nil).where(slug: key).or(Course.where(program_id: nil, code: key)).find_each { |course| course.update!(program: program) }
      end
      program.program_enrollments.active.find_each(&:fan_out!)
    end
  end

  def to_param = slug
  def tier_name = self.class.tier(tier)&.name || tier

  # Classes are the program's courses. None yet means "Coming".
  def coming? = courses.empty?
  def on_sale? = published? && !coming? && price_cents.present?
  def price = price_cents ? format("$%.2f", price_cents / 100.0).sub(/\.00\z/, "") : nil

  # For pages: the owner of the site, a student holding the program, or one
  # who already owns every class in it (bought the classes before programs).
  def owned_by?(user)
    return false unless user
    user.admin? || user.holds_program?(self) || (!coming? && courses.all? { |course| user.enrolled_in?(course) })
  end
end
