# The crest's neural tree, drawn from crest_build_v5.py geometry, as a progress
# map (Prof. Duarte's portal spec): roots = foundation courses, hidden nodes =
# Gates 1-2, limb nodes = Gates 3-4, leader = hiring check, core = stage closed,
# leaves = progress through the current stage.
class CrestTree
  CX = 200
  W_BRANCH, W_TWIG = 7, 4.5
  NODE_R, CROWN_R = 8, 9.5

  LEFT = [
    [ "M", [ [ 200, 342 ] ] ],
    [ "Q", [ [ 176, 343 ], [ 138, 350 ] ] ],
    [ "Q", [ [ 174, 334 ], [ 183, 304 ] ] ],
    [ "C", [ [ 186, 292 ], [ 187, 280 ], [ 189, 262 ] ] ],
    [ "C", [ [ 170, 254 ], [ 146, 234 ], [ 114, 210 ] ] ],
    [ "Q", [ [ 112, 201 ], [ 120, 199 ] ] ],
    [ "C", [ [ 148, 212 ], [ 172, 228 ], [ 190, 240 ] ] ],
    [ "C", [ [ 193, 214 ], [ 194, 170 ], [ 196, 128 ] ] ],
    [ "Q", [ [ 200, 122 ], [ 200, 122 ] ] ]
  ].freeze

  CORE = [ CX, 250 ].freeze
  TOP = [ CX, 128 ].freeze
  LIMB = [ 118, 204 ].freeze
  F1, F2, F3 = [ 80, 172 ], [ 116, 140 ], [ 162, 98 ]
  EDGES_L = [
    [ LIMB, [ 96, 196 ], F1, W_BRANCH ], [ LIMB, [ 112, 170 ], F2, W_BRANCH ], [ TOP, [ 178, 116 ], F3, W_BRANCH ],
    [ [ 152, 226 ], [ 138, 240 ], [ 126, 246 ], W_TWIG ], [ [ 193, 186 ], [ 172, 176 ], [ 156, 176 ], W_TWIG ]
  ].freeze
  LEAVES_L = [
    [ F1, 186, 1.05 ], [ F1, 142, 0.85 ], [ F2, 138, 1.05 ], [ F2, 96, 0.85 ],
    [ F3, 122, 1.05 ], [ F3, 80, 0.8 ], [ [ 126, 246 ], 238, 0.9 ], [ [ 156, 176 ], 150, 0.85 ]
  ].freeze
  LEAVES_C = [ [ TOP, 90, 1.15 ], [ TOP, 52, 0.8 ], [ TOP, 128, 0.8 ] ].freeze
  HID = [ [ 182, 322 ], [ 218, 322 ] ].freeze
  ROOTS_L = [ [ HID[0], [ 154, 340 ], [ 128, 362 ] ], [ HID[0], [ 172, 352 ], [ 164, 372 ] ] ].freeze
  ROOTS_C = [ [ HID[0], [ 192, 352 ], [ 200, 376 ] ], [ HID[1], [ 208, 352 ], [ 200, 376 ] ] ].freeze

  FOUNDATION = [ "CS 090", "CS 101", "MA 150" ].freeze

  attr_reader :leaves_lit, :gates_passed, :roots_lit, :stage_closed, :facts

  # leaves_lit: 0..LEAF_COUNT, gates_passed: 0..5 (5 = hiring check), roots_lit: 0..5
  def initialize(leaves_lit: 0, gates_passed: 0, roots_lit: 0, stage_closed: false, facts: {})
    @leaves_lit, @gates_passed, @roots_lit, @stage_closed, @facts = leaves_lit, gates_passed, roots_lit, stage_closed, facts
  end

  def self.for(user)
    snap = user.transcript_snapshot
    stats = ProgressStats.new(user)
    target = snap&.stage_hours_target.to_i
    progress = target.positive? ? (stats.total_hours / target) : 0
    done = user.course_records.select(&:finished?).map(&:code)
    roots = FOUNDATION.count { |c| done.include?(c) } + (done - FOUNDATION).size
    gates = Badges.gates_passed(user)
    new(
      leaves_lit: [ (progress * leaf_count).floor, leaf_count ].min,
      gates_passed: gates, roots_lit: [ roots, 5 ].min, stage_closed: false,
      facts: {
        stage: snap&.phase.to_s.split("(").first.to_s.strip.presence || "Stage 1",
        hours: stats.total_hours, target: target,
        next_gate: snap&.next_gate_name, gate_days: snap&.days_to_next_gate
      }
    )
  end

  def self.leaf_count = LEAVES_L.size * 2 + LEAVES_C.size

  def caption
    parts = [ facts[:stage] ]
    parts << "#{format('%.2f', facts[:hours].to_f).sub(/\.?0+\z/, '')} of #{facts[:target]} hours" if facts[:target].to_i.positive?
    parts << "#{facts[:next_gate]} in #{facts[:gate_days]} days" if facts[:next_gate] && facts[:gate_days]
    parts.compact.join(" · ")
  end

  # The honest rule behind the leaves, shown under the tree.
  def leaf_rule
    target = facts[:target].to_i
    return "Leaves light up as you log study hours." unless target.positive?
    per = (target / self.class.leaf_count.to_f).round
    "One leaf lights for about every #{per} hours of logged study. Leaves track hours, not lessons."
  end

  def to_svg(size: 300, title: "Your progress tree")
    leaves = LEAVES_L + LEAVES_L.map { |b, a, s| [ mirror(b), 180 - a, s ] } + LEAVES_C
    # Fill from the lowest twig upward, alternating sides (spec: the crown grows evenly).
    order = leaves.each_index.sort_by { |i| [ -leaves[i][0][1], leaves[i][0][0] < CX ? 0 : 1, i ] }
    rank = order.each_with_index.to_h

    parts = []
    parts << %(<path class="ct-trunk" d="#{trunk_path}"/>)
    roots = ROOTS_L + ROOTS_L.map { |a, c, b| [ mirror(a), mirror(c), mirror(b) ] } + ROOTS_C
    roots.each_with_index do |(a, c, b), i|
      lit = i < roots_lit
      parts << qline(a, c, b, W_BRANCH, "ct-edge#{' is-lit' if lit}", lit ? "Root #{i + 1}: foundation course finished" : "Root #{i + 1}: lights when a foundation course finishes")
    end
    edges = EDGES_L + EDGES_L.map { |a, c, b, w| [ mirror(a), mirror(c), mirror(b), w ] }
    edges.each { |a, c, b, w| parts << qline(a, c, b, w, "ct-edge ct-branch#{' is-lit' if leaves_lit.positive?}") }

    leaves.each_with_index do |(b, ang, s), i|
      r = rank[i]
      state = r < leaves_lit ? " is-lit" : (r == leaves_lit ? " is-next" : "")
      parts << leaf(b, ang, s, "ct-leaf#{state}", r < leaves_lit ? "Stage progress" : (r == leaves_lit ? "Next leaf: keep logging study" : "Unlit leaf"))
    end

    gate_nodes = { 1 => HID[0], 2 => HID[1], 3 => LIMB, 4 => mirror(LIMB), 5 => TOP }
    crown = [ F1, F2, F3 ].flat_map { |p| [ p, mirror(p) ] }
    crown.each { |p| parts << circle(p, CROWN_R, "ct-node#{' is-lit' if leaves_lit.positive?}", nil) }
    roots.map(&:last).uniq.each { |p| parts << circle(p, NODE_R, "ct-node ct-root-tip", nil) }
    gate_nodes.each do |n, p|
      label = n == 5 ? "Hiring check" : "Gate #{n}"
      lit = gates_passed >= n
      nxt = gates_passed + 1 == n
      parts << circle(p, n <= 2 ? NODE_R + 1 : CROWN_R, "ct-node ct-gate#{' is-lit' if lit}#{' is-next-gate' if nxt}",
                      lit ? "#{label}: passed" : (nxt && facts[:gate_days] ? "#{label}: #{facts[:gate_days]} days to go" : "#{label}: not yet"))
    end
    parts << hexfork
    %(<svg class="crest-tree" viewBox="24 60 352 330" width="#{size}" height="#{(size * 330 / 352.0).round}" role="img" aria-label="#{ERB::Util.h(title)}: #{ERB::Util.h(caption)}" xmlns="http://www.w3.org/2000/svg">#{parts.join}</svg>).html_safe # every interpolated text above is escaped
  end

  private
    def mirror(p) = [ 2 * CX - p[0], p[1] ]
    def f(p) = format("%.1f %.1f", *p)

    def trunk_path
      d = LEFT.map { |cmd, pts| "#{cmd} #{pts.map { |p| f(p) }.join(' ')}" }
      segs = LEFT[1..]
      starts = LEFT[0...-1].map { |_, pts| pts.last }
      segs.zip(starts).reverse_each do |(cmd, pts), start|
        ctrl = pts[0...-1].map { |p| mirror(p) }.reverse
        d << "#{cmd} #{(ctrl + [ mirror(start) ]).map { |p| f(p) }.join(' ')}"
      end
      d.join(" ") + " Z"
    end

    def tip(text) = text ? "<title>#{ERB::Util.h(text)}</title>" : ""

    def qline(a, c, b, w, klass, title = nil)
      %(<path class="#{klass}" d="M#{f(a)} Q#{f(c)} #{f(b)}" stroke-width="#{w}">#{tip(title)}</path>)
    end

    def circle(p, r, klass, title)
      %(<circle class="#{klass}" cx="#{p[0]}" cy="#{p[1]}" r="#{r}">#{tip(title)}</circle>)
    end

    def leaf(base, ang, s, klass, title, len = 44, wid = 21)
      t = ang * Math::PI / 180
      dx, dy = Math.cos(t), -Math.sin(t)
      px, py = -dy, dx
      l, w = len * s, wid * s
      b = base
      tp = [ b[0] + dx * l, b[1] + dy * l ]
      c1 = [ b[0] + dx * l * 0.25 + px * w * 0.62, b[1] + dy * l * 0.25 + py * w * 0.62 ]
      c2 = [ b[0] + dx * l * 0.75 + px * w * 0.5, b[1] + dy * l * 0.75 + py * w * 0.5 ]
      c3 = [ b[0] + dx * l * 0.75 - px * w * 0.5, b[1] + dy * l * 0.75 - py * w * 0.5 ]
      c4 = [ b[0] + dx * l * 0.25 - px * w * 0.62, b[1] + dy * l * 0.25 - py * w * 0.62 ]
      %(<path class="#{klass}" d="M#{f(b)} C#{f(c1)} #{f(c2)} #{f(tp)} C#{f(c3)} #{f(c4)} #{f(b)}Z">#{tip(title)}</path>)
    end

    def hexfork(r = 21)
      c = CORE
      pts = (0..5).map { |i| a = (30 + 60 * i) * Math::PI / 180; format("%.1f,%.1f", c[0] + r * Math.cos(a), c[1] + r * Math.sin(a)) }.join(" ")
      lit = stage_closed ? " is-lit" : ""
      s = %(<g class="ct-core#{lit}"><title>#{stage_closed ? 'Stage closed' : 'Core: glows when this stage closes'}</title><polygon points="#{pts}"/>)
      [ -150, -30, 90 ].each do |deg|
        a = deg * Math::PI / 180
        s << format(%(<line x1="%d" y1="%d" x2="%.1f" y2="%.1f"/>), c[0], c[1], c[0] + (r - 6) * Math.cos(a), c[1] + (r - 6) * Math.sin(a))
      end
      s << %(<circle cx="#{c[0]}" cy="#{c[1]}" r="6.5"/></g>)
    end
end
