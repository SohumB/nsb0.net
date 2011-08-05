# Adapt a dalli client to fit OpenID::Store::Memcache's expectations.
#
# See https://github.com/openid/ruby-openid/issues/#issue/8
class DalliAdapter
  attr_accessor :dalli_client

  def initialize(dalli_client)
    @dalli_client = dalli_client
  end

  # Replaces boolean return values with strings.
  #
  # True becomes 'STORED', false becomes the empty string.  Other values
  # are left unchanged.
  def add(*args, &block)
    result = dalli_client.send :add, *args, &block
    if result == true
      'STORED'
    elsif result == false
      ''
    else
      result
    end
  end

  # Replaces true and nil return values with strings.
  #
  # True becomes 'DELETED', nil becomes the empty string.  Other values
  # are left unchanged.
  def delete(*args, &block)
    result = dalli_client.send :delete, *args, &block
    if result == true
      'DELETED'
    elsif result.nil?
      ''
    else
      result
    end
  end

  # Send everything else along unchanged.
  def method_missing(name, *args, &block)
    dalli_client.send name, *args, &block
  end
end
