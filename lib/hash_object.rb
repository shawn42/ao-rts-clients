require 'forwardable'
class HashObject
  extend Forwardable
  def_delegators :@hash, :[], :[]=, :each, :to_s

  def initialize(hash)
    @hash = {}
    hash.each do |k,v|
      @hash[k.to_s] = v
    end
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
