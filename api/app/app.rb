require 'json'
require 'logger'
require 'rack/ssl'
require 'sinatra'
require 'sinatra/base'

# Load helper methods
Dir.glob('./helpers/*.rb').each { |file| require file }

# Sinatra Application Class
class API < Sinatra::Base
  # Force HTTPS
  use Rack::SSL

  # Logging
  configure :production, :development do
    enable :logging
  end

  configure :test do
    set :logging, ::Logger::ERROR
  end

  configure :development do
    set :logging, ::Logger::DEBUG
  end

  configure :production do
    set :logging, ::Logger::INFO
  end

  # Intitial deployment
  unless ENV['RACK_ENV'] == 'test'
    log.info 'Initial deployment'
    deploy
  end

  get '/' do
    'Nothing here! Yet!'
  end

  post '/travis' do
    payload = JSON.parse(params[:payload])
    build   = payload['number']
    branch  = payload['branch']
    repo    = payload['repository']['name']

    verify_travis_request
    async_deploy
    log.info "Deployment requested from build ##{build} for the #{branch} " \
             "branch of repository #{repo}"
    'Deployment started'
  end

  post '/github' do
    request.body.rewind
    payload_body = request.body.read
    verify_github_signature(payload_body)

    payload = JSON.parse(params[:payload])
    async_deploy
    log.info "Requested by GitHub user @#{payload['sender']['login']}"

    'Deployment started'
  end

  post '/slack' do
    token   = params.fetch('token').strip
    user    = params.fetch('user_name').strip
    channel = params.fetch('channel_name').strip
    command = params.fetch('command').strip
    text    = params.fetch('text').strip

    if token == config['slack_token']
      log.info "Authorized request from slacker @#{user} on channel ##{channel}"
    else
      log.warn "Unauthorized token received from slacker @#{user}"
    end

    case command
    when '/rhea'
      case text
      when 'deploy'
        # Only use the threaded deployment because of the short timeout
        async_deploy
        'Deployment started :thumbsup:'
      else
        "I don't understand '#{text}' :cry:"
      end
    else
      "Unknown command '#{command}' :cry:"
    end
  end

  # Show environment info
  get '/env' do
    protected!
    if params[:json] == 'yes'
      content_type :json
      ENV.to_h.to_json
    else
      'Environment (as <a href="/env?json=yes">JSON</a>):<ul>' +
        ENV.each.map { |k, v| "<li><b>#{k}:</b> #{v}</li>" }.join + '</ul>'
    end
  end

  get '/status' do
    'Alive'
  end
end # class API
