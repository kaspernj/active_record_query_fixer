class ActiveRecordQueryFixer
  attr_reader :query

  def self.fix(query)
    new(query: query).fix.query
  end

  def initialize(args)
    @query = args.fetch(:query)
  end

  def fix
    fix_order_group
    fix_order_select_distinct
    self
  end

  def fix_order_group
    return if @query.values[:group].empty?

    changed = false
    @query.values[:order].each do |order|
      next if !order.is_a?(Arel::Nodes::Ascending) &&
          !order.is_a?(Arel::Nodes::Descending)

      @query = @query.group("#{order.expr.relation.right}.#{order.expr.name}")
      changed = true
    end

    self
  end

  def fix_order_select_distinct
    return unless @query.values[:distinct]

    changed = false
    @query.values[:order].each do |order|
      next if !order.is_a?(Arel::Nodes::Ascending) &&
          !order.is_a?(Arel::Nodes::Descending)

      @query = @query.select("#{order.expr.relation.right}.#{order.expr.name}")
      changed = true
    end

    @query = @query.select("#{@query.table_name}.*") if changed
    self
  end
end
