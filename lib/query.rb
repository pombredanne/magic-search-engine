require_relative "query_parser"
require_relative "search_results"

class Date
  # Any kind of key for sorting
  def to_i_sort
    to_time.to_i
  end
end

class Query
  def initialize(query_string)
    @cond, @metadata = QueryParser.new.parse(query_string)
    if @metadata[:time]
      @cond = ConditionAnd.new(@cond, ConditionPrint.new("<=", @metadata[:time]))
    end
    if @cond
      raise "No condition present for #{query_string}" unless @cond
    else
      # No search query? OK, we'll just return all cards except extras
    end

    # puts "Parse #{query_string} -> #{@cond}"
  end

  # What is being done with @cond.metadata= is awful beyond belief...
  def search(db)
    logger = Set[]
    if @cond
      @cond.metadata = @metadata.merge(fuzzy: nil, logger: logger)
      results = @cond.search(db)
      if results.empty?
        @cond.metadata = @metadata.merge(fuzzy: db, logger: logger)
        results = @cond.search(db)
      end
    else
      results = db.printings
    end

    results = results.sort_by do |c|
      case @metadata[:sort]
      when "new"
        [c.set.regular? ? 0 : 1, -c.release_date.to_i_sort]
      when "old"
        [c.set.regular? ? 0 : 1, c.release_date.to_i_sort]
      when "newall"
        [-c.release_date.to_i_sort]
      when "oldall"
        [c.release_date.to_i_sort]
      when "cmc"
        [c.cmc ? 0 : 1, -c.cmc.to_i]
      when "pow"
        [c.power ? 0 : 1, -c.power.to_i]
      when "tou"
        [c.toughness ? 0 : 1, -c.toughness.to_i]
      else # "name" or unknown key
        []
      end + [c.name, c.set.regular? ? 0 : 1, -c.release_date.to_i_sort, c.set.name, c.number.to_i, c.number]
    end
    SearchResults.new(results, logger, ungrouped?)
  end

  def to_s
    [
      @cond.to_s,
      ("time:#{maybe_quote(@metadata[:time])}" if @metadata[:time]),
      ("sort:#{@metadata[:sort]}" if @metadata[:sort]),
    ].compact.join(" ")
  end

  def ==(other)
    # structural equality, subclass if you need something fancier
    self.class == other.class and
      instance_variables == other.instance_variables and
      instance_variables.all?{|ivar| instance_variable_get(ivar) == other.instance_variable_get(ivar) }
  end

  private

  def ungrouped?
    !!@metadata[:ungrouped]
  end

  def maybe_quote(text)
    if text.is_a?(Date)
      '"%d.%d.%d"' % [text.year, text.month, text.day]
    elsif text =~ /\A[a-zA-Z0-9]+\z/
      text
    else
      text.inspect
    end
  end
end
