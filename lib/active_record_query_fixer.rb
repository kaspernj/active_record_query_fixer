require "dig_bang"
require "pg_query"

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
    fix_select_group if @query.values[:select] && @query.values[:group]

    self
  end

  def fix_select_group
    select_targets.each do |select_target|
      fields = select_target.dig!("ResTarget", "val", "ColumnRef", "fields")
      next if fields.length != 2

      table = fields[0].dig("String", "str")
      column = fields[1].dig("String", "str")

      if column
        # A table and a column has been selected - make sure to group by that
        @query = @query.group("#{table}.#{column}")
      elsif fields[1].key?("A_Star")
        # A table and a star has been selected - assume the primary key is called "id" and group by that
        @query = @query.group("#{table}.id")
      end
    end

    self
  end

  def fix_order_group
    @query = @query.group(@query.model.arel_table[@query.model.primary_key])

    sort_targets.each do |sort_target|
      fields = sort_target.dig("SortBy", "node", "ColumnRef", "fields")
      next if !fields || fields.length != 2

      table = fields.dig(0, "String", "str")
      column = fields.dig(1, "String", "str")

      @query = @query.group("#{table}.#{column}") if table && column
    end

    self
  end

  def fix_order_select_distinct
    changed = false

    sort_targets.each do |sort_target|
      fields = sort_target.dig("SortBy", "node", "ColumnRef", "fields")
      next if !fields || fields.length != 2

      table = fields.dig(0, "String", "str")
      column = fields.dig(1, "String", "str")

      next if !table || !column

      @query = @query.select("#{table}.#{column} AS active_record_query_fixer_#{@count_select}")
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

  def fix_order_group?
    @query.values[:joins].blank? && @query.values[:distinct].present? && @query.values[:order].present? ||
      @query.values[:group].present? && @query.values[:order].present?
  end

  def fix_order_select_distinct?
    @query.values[:distinct].present? && @query.values[:order].present?
  end

  def fix_reference_group?
    @query.values[:references].present? && @query.values[:group].present?
  end

  def parsed_query
    @parsed_query ||= PgQuery.parse(@query.to_sql)
  end

  def select_statement
    @select_statement ||= parsed_query.tree.dig!(0, "RawStmt", "stmt", "SelectStmt")
  end

  def select_targets
    @select_targets ||= select_statement.fetch("targetList")
  end

  def sort_targets
    return [] unless select_statement.key?("sortClause")

    @sort_targets ||= parsed_query.tree.dig!(0, "RawStmt", "stmt", "SelectStmt", "sortClause")
  end
end

ActiveRecord::Relation.include ActiveRecordQueryFixer::RelationExtentions
