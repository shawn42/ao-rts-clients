class HashObject
  def initialize(hash)
    @hash = {}
    hash.each do |k,v|
      @hash[k.to_s] = v
    end
  end

  def each(&blk)
    @hash.each &blk
  end

  def []=(k,v)
    @hash[k.to_s] = v
  end
  def [](k)
    @hash[k.to_s]
  end

  def method_missing(name, *args)
    val = @hash[name.to_s]
    if val.is_a? Hash
      val = HashObject.new val
    elsif val.is_a? Array
      val = val.map{|v|HashObject.new v}
    end
    @hash[name.to_s] =  val
    val
  end

end
