require 'oauth2'
require 'webrick'

FREEAGENT_APP_ID = ENV['FREEAGENT_APP_ID']
FREEAGENT_APP_SECRET = ENV['FREEAGENT_APP_SECRET']

TOKEN_FILE = './.token.yml'

module Freeagent
  class API
    def initialize
      if FREEAGENT_APP_ID.nil? || FREEAGENT_APP_ID.empty?
        raise ArgumentError, 'FREEAGENT_APP_ID is unset'
      end
      if FREEAGENT_APP_SECRET.nil? || FREEAGENT_APP_SECRET.empty?
        raise ArgumentError, 'FREEAGENT_APP_SECRET is unset'
      end

      @token = reload || authorize
      File.write TOKEN_FILE, @token.to_hash.to_hash.to_yaml
    end

    private
    def reload
      if File.exist? TOKEN_FILE
        OAuth2::AccessToken.from_hash(client, YAML.unsafe_load_file(TOKEN_FILE)).refresh
      end
    rescue OAuth2::Error
      nil
    end

    def client
      @client ||= OAuth2::Client.new(FREEAGENT_APP_ID, FREEAGENT_APP_SECRET,
        site: 'https://api.freeagent.com/v2/',
        authorize_url: 'approve_app',
        token_url: 'token_endpoint'
      )
    end

    def authorize
      receiver = WEBrick::HTTPServer.new(Port: 0)
      receiver_url = "http://localhost:#{receiver.config[:Port]}/"
      url = client.auth_code.authorize_url(redirect_uri: receiver_url)
      puts "Go and authorize at #{url}, I'm waiting..."

      access_code = nil
      receiver.mount_proc '/' do |req, res|
        # TODO: parse redirect response...
        access_code = req.query['code']
        receiver.shutdown
      end

      Signal.trap('INT') do
        receiver.shutdown
      end

      receiver.start
      raise if access_code.nil?

      client.auth_code.get_token(access_code, redirect_uri: receiver_url)
    end

    def get *parts, **params
      relatives = parts.map(&:to_s).join('/')
      uri = URI.parse(relatives)
      puts "GET #{uri}"
      res = @token.get(uri, params: params, headers: {'Accept': 'application/json'})
      data = res.parsed
      if res.headers.include? 'Link'
        data._links = res.headers['Link'].split(", ").map do |link|
          url, rel = link.split('; rel=')
          [rel.gsub(/^'|'$/, ''), URI::parse(url.gsub(/^<|>$/, ''))]
        end.to_h
      end
      data
    rescue => err
      if err.response.status == 429
        retry_after = err.response.headers['retry-after'].to_i
        STDERR.puts "Rate limited; sleeping for #{retry_after}"
        sleep retry_after
        retry
      end
    end

    def get_pages *path, **params
      Enumerator.new do |yielder|
        loop do
          res = get(*path, **{per_page: 100}.update(params))
          yielder << res
          break if res._links.nil? || res._links.next.nil?
          params = URI::decode_www_form(res._links.next.query).to_h
        end
      end
    end

    def post *parts, **params
      data = parts.pop
      relatives = parts.map(&:to_s).join('/')
      uri = URI.parse(relatives)
      puts "POST #{uri}"
      body = data.to_json
      @token.post(uri, body: body, params: params, headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}).parsed
    end

    def delete *parts, **params
      relatives = parts.map(&:to_s).join('/')
      uri = URI.parse(relatives)
      puts "DELETE #{uri}"
      @token.delete(uri, params: params, headers: {'Accept': 'application/json'})
    end

    public
    def first_accounting_year_end
      Date.parse get('company').company.first_accounting_year_end
    end

    def periods year
      get('payroll', year).periods
    end

    def payslips year, period
      get('payroll', year, period).period.payslips
    end

    def profiles year
      get('payroll_profiles', year).profiles
    end

    def projects
      get_pages('projects').flat_map(&:projects)
    end

    def tasks project
      get_pages('tasks', project: project.url).flat_map(&:tasks)
    end

    def timeslips user, project, task, from, to
      get_pages('timeslips', user: user.url, project: project.url, task: task.url, from_date: from.to_s, to_date: to.to_s).flat_map(&:timeslips)
    end

    def create_timeslip user, project, task, dated, hours
      post('timeslips', {
        'task' => task.url,
        'project' => project.url,
        'user' => user.url,
        'dated_on' => dated.to_s,
        'hours' => hours,
      })
    end

    def batch_create_timeslips timeslips
      post('timeslips', {'timeslips' => timeslips})
    end

    def delete_timeslip timeslip
      id = timeslip.url.split('/').last
      delete('timeslips', id)
    end

    def users
      get_pages('users').flat_map(&:users)
    end

    def user id
      get('users', id).user
    end

    def profile year, user
      get('payroll_profiles', year, user: user)
    end
  end
end
