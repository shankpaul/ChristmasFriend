require 'sinatra'
require "sinatra/cookies"
require 'omniauth-facebook'
require 'koala'
require './helpers/get_post'

enable :sessions

set :protection, :except => :frame_options

configure do
  set :redirect_uri, nil
end

# Used when app is browsed outside FB's iframe
# When auth fails in FB, POST /canvas/ redirects to /auth/failure
OmniAuth.config.on_failure = lambda do |env|
  [302, {'Location' => '/auth/failure', 'Content-Type' => 'text/html'}, []]
end

# This might come from DB
APP_ID = "1402943853278306"
APP_SECRET = "a90c7e1ad7fecc7366d94fff2ed4d93b"

use OmniAuth::Builder do
  provider :facebook, APP_ID, APP_SECRET, { :scope => 'email, status_update, publish_stream,user_birthday,friends_birthday' }
end

get_post '/find_friend' do
  graph = Koala::Facebook::API.new(session['fb_token'])
  @profile = graph.get_object("me")
  friends  =  graph.get_connections("me", "friends",:fields=>"gender, birthday")
  suggestion = []
  puts @profile["birthday"]
  my_dob = Date.strptime @profile["birthday"], '%m/%d/%Y'
  friends.each do |friend|
    begin
      friend_dob = Date.strptime friend["birthday"], '%m/%d/%Y'
      if @profile['gender'] == 'male' && friend['gender'] == 'female'
        if friend_dob.year <= my_dob.year && friend_dob.year >= my_dob.year-5
          suggestion << friend
        end
      elsif @profile['gender'] == 'female'
        if(params[:gender] == 'all') || (params[:gender] == 'female' && friend['gender'] == 'female')
          if friend_dob.year <= my_dob.year+5 && friend_dob.year >= my_dob.year-5
            suggestion << friend
          end
        end
      end 
    rescue Exception => e
      puts e.message
    end
  end
  @friend = suggestion[Random.rand(suggestion.count)]
  @friend = graph.get_object(@friend['id'])
  puts @friend.inspect
  #erb :friend
end   

# This content is accessible for everyone
# but only people logged in with FB credentials
#   would be able to Like links and the page
get_post '/' do
 erb :index
end

# This is called after successful authentication via /auth/facebook/
get '/auth/facebook/callback' do

  fb_auth = request.env['omniauth.auth']
  session['fb_auth'] = fb_auth
  session['fb_token'] = cookies[:fb_token] = fb_auth['credentials']['token']
  session['fb_error'] = nil
  redirect '/'
end

# If user doesn't grant us access or 
#   there's some failure regarding auth, 
#   this handles it
get '/auth/failure' do
  clear_session
  session['fb_error'] = 'In order to use all the Facebook features in this site you must allow us access to your Facebook data...<br />'
  redirect '/'
end

get '/login' do
  if settings.redirect_uri
    # we're in FB
    erb :dialog_oauth
  else
    # we aren't in FB (standalone app)
    redirect '/auth/facebook'
  end
end

get '/logout' do
  clear_session
  redirect '/'
end

# access point from FB, Canvas URL and Secure Canvas URL must be point to this route
# Canvas URL: http://your_app/canvas/
# Secure Canvas URL: https://your_app:443/canvas/
post '/canvas/' do

  # User didn't grant us permission in the oauth dialog
  redirect '/auth/failure' if request.params['error'] == 'access_denied'

  # see /login
  settings.redirect_uri = 'https://apps.facebook.com/faceboku/'

  # Canvas apps send the 'code' parameter
  # We use it to know if we're accessing the app from FB's iFrame
  # If so, we try to autologin
  url = request.params['code'] ? "/auth/facebook?signed_request=#{request.params['signed_request']}&state=canvas" : '/login'
  redirect url
end

def clear_session
  session['fb_auth'] = nil
  session['fb_token'] = nil
  session['fb_error'] = nil
  cookies[:fb_token] = nil
end
