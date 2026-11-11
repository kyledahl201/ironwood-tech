# Step-through visualizers. Their examples are deliberately not lab exercises,
# so they never show an exercise's answer.
class VisualizersController < ApplicationController
  Tool = Data.define(:id, :title, :eyebrow, :blurb, :inputs)
  Input = Data.define(:name, :label, :suffix, :type, :value, :max)

  TOOLS = [
    Tool.new("loop", "Loop tracer", "Arrays and .each",
             "Watch Ruby walk through .each one line at a time and count the long words.",
             [ Input.new("words", "Words", nil, "text", "oak, copper, owl, midnight", 80), Input.new("limit", "Longer than", "letters", "number", "3", 20) ]),
    Tool.new("hash", "Hash lookup", "Hashes, keys and values",
             "See how a hash finds a value by its key, and what happens when the key isn't there.",
             [ Input.new("pairs", "Pairs", nil, "text", "oak: 4, copper: 9, owl: 2", 80), Input.new("key", "Look up", nil, "text", "owl", 20) ]),
    Tool.new("stack", "Call stack", "Methods calling methods",
             "Follow a method call into another method and back out, and watch each return value travel.",
             [ Input.new("a", "First number", nil, "number", "3", 99), Input.new("b", "Second number", nil, "number", "4", 99) ])
  ].index_by(&:id).freeze

  def index
    @tools = TOOLS.values
  end

  def show
    @tool = TOOLS.fetch(params[:id])
    @tools = TOOLS.values
  end
end
