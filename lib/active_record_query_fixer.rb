require "dig_bang"

class ActiveRecordQueryFixer
  autoload :RelationExtentions, "#{__dir__}/active_record_query_fixer/relation_extentions"

  attr_reader :query

  delegate :connection, to: :query
  delegate :quote_column_name, :quote_table_name, to: :connection

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
    fix_select_group if query.values[:select] && query.values[:group]

    self
  end

  def fix_select_group
    select_targets.each do |select_target|
      fields = select_target.res_target.val.column_ref.fields
      next if !fields || fields.length != 2

      table = fields[0].string.str
      column = fields[1].string&.str

      if column
        # A table and a column has been selected - make sure to group by that
        @query = query.group("#{quote_table_name(table)}.#{quote_column_name(column)}")
      elsif fields[1].a_star
        # A table and a star has been selected - assume the primary key is called "id" and group by that
        @query = query.group("#{quote_table_name(table)}.#{quote_column_name("id")}")
      end
    end

    self
  end

  def fix_order_group
    @query = query.group(query.model.arel_table[query.model.primary_key])

    sort_targets.each do |sort_target|
      fields = sort_target.sort_by.node.column_ref&.fields

      next if !fields || fields.length != 2

      table = fields[0].string.str
      column = fields[1].string.str

      @query = query.group("#{quote_table_name(table)}.#{quote_column_name(column)}") if table && column
    end

    self
  end

  def fix_order_select_distinct
    select_appends = []

    sort_targets.each do |sort_target|
      fields = sort_target.sort_by.node.column_ref.fields
      next if !fields || fields.length != 2

      table = fields[0].string.str
      column = fields[1].string.str

      next if !table || !column

      select_appends << "#{quote_table_name(table)}.#{quote_column_name(column)} AS active_record_query_fixer_#{@count_select}"

      @count_select += 1
    end

    # Start by prepending a wild-card select before doing the fix-selects to avoid any issues with `DISTINCT COUNT`
    prepend_table_wildcard if !table_wildcard_prepended? && select_appends.any? && query.values[:select].blank?

    select_appends.each do |select_append|
      @query = query.select(select_append)
    end

    self
  end

  def fix_reference_group
    @query = query.group(query.model.arel_table[query.model.primary_key])

    query.values[:references].each do |reference|
      @query = query.group("#{quote_table_name(reference)}.#{quote_column_name("id")}")
    end

    self
  end

private

  def fix_order_group?
    query.values[:joins].blank? && query.values[:distinct].present? && query.values[:order].present? ||
      query.values[:group].present? && query.values[:order].present?
  end

  def fix_order_select_distinct?
    query.values[:distinct].present? && query.values[:order].present?
  end

  def fix_reference_group?
    query.values[:references].present? && query.values[:group].present?
  end

  def parsed_query
    require "pg_query" unless defined?(PgQuery)
    @parsed_query ||= PgQuery.parse(query.to_sql)
  end

  # Prepends 'table_name.*' to the query. It needs to be pre-pended in case a `COUNT` or another aggregate function has been added to work with `DISTINCT`.
  def prepend_table_wildcard
    old_select = query.values[:select]&.clone || []
    old_select = old_select.keep_if { |select_statement| select_statement != select_table_wildcard_sql }

    @query = query.except(:select).select(select_table_wildcard_sql)

    old_select.each do |select_statement|
      @query = query.select(select_statement)
    end
  end

  def select_table_wildcard_sql
    @select_table_wildcard_sql ||= "#{quote_table_name(query.table_name)}.*"
  end

  def table_wildcard_prepended?
    query.values[:select]&.first == select_table_wildcard_sql
  end

  def select_statement
    @select_statement ||= parsed_query.tree.stmts.fetch(0).stmt.select_stmt
  end

  def select_targets
    @select_targets ||= select_statement.target_list
  end

  def sort_targets
    @sort_targets ||= select_statement.sort_clause
  end
end

ActiveRecord::Relation.include ActiveRecordQueryFixer::RelationExtentions
