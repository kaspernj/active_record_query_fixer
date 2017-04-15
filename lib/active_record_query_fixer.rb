class ActiveRecordQueryFixer
  attr_reader :query

  def initialize(args)
    @query = args.fetch(:query)
  end
end
