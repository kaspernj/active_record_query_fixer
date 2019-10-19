class ActiveRecordQueryFixer
  autoload :RelationExtentions, "#{__dir__}/active_record_query_fixer/relation_extentions"

  attr_reader :query

  def self.fix(query)
    new(query: query).fix.query
  end

  def initialize(args)
    @query = args.fetch(:query)
    @count_select = 0
  end

  def fix
    fix_reference_group if fix_reference_group?
    fix_order_group if fix_order_group?
    fix_order_select_distinct if fix_order_select_distinct?
    self
  end

  def fix_order_group
    @query = @query.group(@query.model.arel_table[@query.model.primary_key])

    @query.values[:order]&.each do |order|
      @query = @query.group(extract_table_and_column_from_expression(order)) if group_by_order?(order) || @query.values[:distinct]
    end

    self
  end

  def fix_order_select_distinct
    changed = false
    @query.values[:order]&.each do |order|
      @query = @query.select("#{extract_table_and_column_from_expression(order)} AS active_record_query_fixer_#{@count_select}")
      changed = true
      @count_select += 1
    end

    @query = @query.select("#{@query.table_name}.*") if changed

    self
  end

  def fix_reference_group
    @query = @query.group(@query.model.arel_table[@query.model.primary_key])

    @query.values[:references].each do |reference|
      @query = @query.group("#{reference}.id")
    end

    self
  end

private

  def extract_table_and_column_from_expression(order)
    if order.is_a?(Arel::Nodes::Ascending) || order.is_a?(Arel::Nodes::Descending)
      if order.expr.relation.respond_to?(:right)
        "#{order.expr.relation.right}.#{order.expr.name}"
      else
        "#{order.expr.relation.table_name}.#{order.expr.name}"
      end
    elsif order.is_a?(String)
      order
    else
      raise "Couldn't extract table and column from: #{order}"
    end
  end

  def fix_order_group?
    @query.values[:joins].blank? && @query.values[:distinct].present? ||
      @query.values[:group].present? && @query.values[:order].present?
  end

  def fix_order_select_distinct?
    @query.values[:distinct].present? && @query.values[:order].present?
  end

  def fix_reference_group?
    @query.values[:references].present? && @query.values[:group].present?
  end

  def group_by_order?(order)
    order.is_a?(String) && !order.match?(/\A\s*(COUNT|SUM)\(/i)
  end
end

ActiveRecord::Relation.include ActiveRecordQueryFixer::RelationExtentions
