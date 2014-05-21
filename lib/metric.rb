class Metric
  include Redised

  def self.all(refresh = false)
    get_list("metrics", refresh)
  end

  def self.top_level_names(refresh = false)
    get_list("top_level_metrics", refresh)
  end

  def self.find(match, max = 100)
    match = match.to_s.strip
    matches = []
    if match.length > 0
      begin
        pattern = /#{match}/i
      rescue RegexpError
        return matches
      end
      all.each do |m|
        if m =~ pattern
          matches << m
        end
        break if matches.length > max
      end
    else
      return top_level_names()
    end
    matches
  end

  private
  def self.get_list(key, refresh = false)
    value = redis.get(key)
    items = value.split("\n") if value
    return items if items && !items.empty? && !refresh
    @metrics = []
    @top_level_metrics = []
    get_metrics_list
    redis.set "metrics", @metrics.join("\n")
    redis.set "top_level_metrics", @top_level_metrics.join("\n")
    instance_variable_get("@#{key}")
  end

  private
  def self.get_metrics_list(prefix = Graphiti.settings.metric_prefix)
    url = URI.parse("#{Graphiti.settings.graphite_base_url}/metrics/index.json")

    puts "Getting #{url}"
    httpclient = HTTPClient.new
    httpclient.set_auth(nil, url.user, url.password) if url.userinfo
    response = httpclient.get(url)

    if response.ok?
      json = JSON.parse(response.content)
      if prefix.nil?
        @metrics = json 
      elsif prefix.kind_of?(Array)
        @metrics = json.grep(/^(#{prefix.map! { |k| Regexp.escape k }.join("|")})/)
      else
        @metrics = json.grep(/^#{Regexp.escape prefix}/)
      end
    else
      # puts "Error fetching #{url}. #{response.inspect}"
	  puts "Error fetching #{url}"
    end
    @metrics.collect! { |metric| 
      metric.gsub(/^\./, '')
    }
    tops = {}
    @metrics.each do |m|
      tops[m.split(".").first] = nil
    end
    @top_level_metrics = tops.keys
    @top_level_metrics.sort
    @metrics.sort
  end

end
