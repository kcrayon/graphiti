require 'uri'
require 'fileutils'

class Graph
  include Redised

  SNAPSHOT_SERVICES = ['s3', 'fs']

  def self.save(uuid=nil, graph_json)
    uuid ||= make_uuid(graph_json)
    aka = set_aka(graph_json, uuid)

    redis.hset("graphs:#{uuid}", "title", graph_json[:title])
    redis.hset("graphs:#{uuid}", "json", graph_json[:json])
    redis.hset("graphs:#{uuid}", "updated_at", Time.now.to_i)
    redis.hset("graphs:#{uuid}", "url", graph_json[:url])
    redis.hset("graphs:#{uuid}", "aka", aka)

    redis.zadd("graphs", Time.now.to_i, uuid)

    uuid
  end

  def self.set_aka(graph_json, uuid)
    aka = graph_json[:title].downcase.gsub(/\s/, "-")

    lua = <<-EOF
      if redis.call("exists", KEYS[1]) == 1 then
        return redis.call("get", KEYS[1]) == ARGV[1]
      else
        return redis.call("set", KEYS[1], ARGV[1])
      end
    EOF

    if !redis.eval(lua, :keys => ["graphs:aka:#{aka}"], :argv => [uuid])
      # Should be safe to clobber here because it has our uuid
      aka = "#{uuid}-#{aka}"
      redis.set("graphs:aka:#{aka}", uuid)
    end

    if graph_json[:aka] && graph_json[:aka] != aka
      # Clean up if the aka has changed
      redis.del("graphs:aka:#{graph_json[:aka]}")
    end

    aka
  end

  def self.find(id)
    hsh = redis.hgetall("graphs:#{id}")

    if hsh.empty?
      # Try to get the graph by aka
      aka = id.downcase.gsub(/\s/, "-")
      id = redis.get("graphs:aka:#{aka}")
      hsh = redis.hgetall("graphs:#{id}")
    end

    hsh["uuid"] = id
    hsh["snapshots"] = redis.zrange("graphs:#{id}:snapshots", 0, -1)

    hsh
  rescue
    nil
  end

  # Fetch and return the image data of a graph
  def self.get_graph_data(uuid)
    return nil unless graph = find(uuid)

    orig_url = URI(graph["url"])
    url = URI(Graphiti.graphite_base_url + [orig_url.path, orig_url.query].compact.join("?"))

    httpclient = HTTPClient.new
    httpclient.set_auth(nil, url.user, url.password) if url.userinfo
    response = httpclient.get(url)

    return false if !response.ok?

    response.content
  end

  def self.snapshot(uuid)
    service = Graphiti.snapshots['service'] if Graphiti.respond_to?(:snapshots)
    if !snapshot_service?(service)
      raise "'#{service}' is not a valid snapshot service (must be one of #{SNAPSHOT_SERVICES.join(', ')})"
    end

    if !(graph_data = get_graph_data(uuid))
      raise "Failed to get graph data for #{uuid}"
    end

    time = (Time.now.to_f * 1000).to_i
    filename = "/snapshots/#{uuid}/#{time}.png"
    image_url = send("store_on_#{service}", graph_data, filename)
    redis.zadd "graphs:#{uuid}:snapshots", time, image_url if image_url
    image_url
  end

  def self.snapshot_service?(service)
    SNAPSHOT_SERVICES.include?(service)
  end

  # upload graph_data to S3 with filename
  def self.store_on_s3(graph_data, filename)
    S3::Request.credentials ||= Graphiti.snapshots
    return false if !S3::Request.upload(filename, StringIO.new(graph_data), 'image/png')
    S3::Request.url(filename)
  end

  # store graph_data at filename, prefixed with Graphiti.snapshots['dir']
  def self.store_on_fs(graph_data, filename)
    directory = File.expand_path(Graphiti.snapshots['dir'])
    fullpath = File.join(directory, filename)
    fulldir = File.dirname(fullpath)
    FileUtils.mkdir_p(fulldir) unless File.directory?(fulldir)
    File.open(fullpath, 'wb') do |file|
      file << graph_data
    end
    image_url = "#{Graphiti.snapshots['public_host']}#{filename}"
  end

  def self.dashboards(uuid)
    redis.smembers("graphs:#{uuid}:dashboards")
  end

  def self.destroy(uuid)
    redis.del "graphs:#{uuid}"
    redis.zrem "graphs", uuid
    self.dashboards(uuid).each do |dashboard|
      Dashboard.remove_graph dashboard, uuid
    end
  end

  def self.all(*graph_ids)
    graph_ids = redis.zrevrange "graphs", 0, -1 if graph_ids.empty?
    graph_ids ||= []
    graph_ids.flatten.collect do |uuid|
      find(uuid)
    end.compact
  end

  def self.make_uuid(graph_json)
    Digest::SHA1.hexdigest(graph_json.inspect + Time.now.to_f.to_s + rand(100).to_s)[0..10]
  end
end
