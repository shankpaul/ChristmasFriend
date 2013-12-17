# ChristmasFriend 1.0.0
# @developer
#   => Shan K Paul <shanpaul06@gmail.com>< http://www.tagprof.com/shan >  
#   => Abhilash M A <abhilash.ma@nuevalgo.com>  

#---------------libraries----------------------
require 'sinatra'
require "sinatra/cookies"
require 'omniauth-facebook'
require 'koala'
require './helpers/get_post'
#-----------------------------------------------

enable :sessions
set :protection, :except => :frame_options
configure do
  set :redirect_uri, nil
end

BASE_URL = "http://localhost:9292/"

OmniAuth.config.on_failure = lambda do |env|
  [302, {'Location' => '/auth/failure', 'Content-Type' => 'text/html'}, []]
end

#---------------App configurations---------------
APP_ID = "1402943853278306"
APP_SECRET = "a90c7e1ad7fecc7366d94fff2ed4d93b"
#------------------------------------------------

use OmniAuth::Builder do
  provider :facebook, APP_ID, APP_SECRET, { :scope => 'email, status_update, publish_stream,user_birthday,friends_birthday' }
end

get '/post' do
  token = params[:token]
  friend = params[:friend]
  me = params[:me]
  convert_to_image token,friend,me
  
end 

get '/convert' do
  token = params[:token]
  friend = params[:friend]
  me = params[:me]
  graph = Koala::Facebook::API.new(session['fb_token'])
  @profile = graph.get_object("me")
  @profile["image"] = graph.get_picture(@profile["id"],:type => "large")
  @friend = graph.get_object(friend)
  @friend["image"] = graph.get_picture(@friend["id"],:type => "large")
  erb :post


end 




#--------------Find your friend page------------
get '/friend' do
  graph = Koala::Facebook::API.new(session['fb_token'])
  @token = session['fb_token']
  puts @token
  @profile = graph.get_object("me")
  @profile["image"] = graph.get_picture(@profile["id"],:type => "large")
  friends  =  graph.get_connections("me", "friends",:fields=>"gender, birthday")
  suggestion = []
  # puts @profile["birthday"]
  my_dob = Date.strptime @profile["birthday"], '%m/%d/%Y'
  friends.each do |friend|
    begin
      friend_dob = Date.strptime friend["birthday"], '%m/%d/%Y'
      if friend_dob.year <= my_dob.year+5 && friend_dob.year >= my_dob.year-5
        suggestion << friend
      end      
    rescue Exception => e
      puts e.message
    end
  end
  @friend = suggestion[Random.rand(suggestion.count)]
  @friend = graph.get_object(@friend['id'])
  @friend["image"] = graph.get_picture(@friend["id"],:type => "large")

  puts @friend.inspect
 erb :friend
  
end   

#-----------------Home page ---------------------------------- 
get_post '/' do
  if session['fb_token']
    graph = Koala::Facebook::API.new(session['fb_token'])
    @profile = graph.get_object("me")
    @profile["image"] = graph.get_picture(@profile["id"],:type => "large")
    erb :index
  else
   redirect '/login'
 end

end

#---------Landing page with fb data from successfull Facebook auth ---------
get '/auth/facebook/callback' do

  fb_auth = request.env['omniauth.auth']
  session['fb_token'] = cookies[:fb_token] = fb_auth['credentials']['token']
  session['fb_error'] = nil
  redirect '/'

end

#-----------Page for auth failure----------------------------
get '/auth/failure' do

  clear_session
  session['fb_error'] = 'If wanna find your christmas friend you need to allow all access permissions'
  redirect '/'

end

#------------------------------------------------------------
get '/login' do
  if settings.redirect_uri
    # inside FB
    erb :dialog_oauth
  else
    # standalone app
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
  settings.redirect_uri = 'https://apps.facebook.com/ChristmasFriend/'

  # Canvas apps send the 'code' parameter
  # We use it to know if we're accessing the app from FB's iFrame
  # If so, we try to autologin
  url = request.params['code'] ? "/auth/facebook?signed_request=#{request.params['signed_request']}&state=canvas" : '/login'
  redirect url
end


def clear_session
  session['fb_token'] = nil
  session['fb_error'] = nil
  cookies[:fb_token] = nil
end

def convert_to_image token,friend,me
  # kit = IMGKit.new("#{BASE_URL}convert?token=#{token}&friend=#{friend}&me=#{me}")
  kit = IMGKit.new("http://localhost:9292/convert?token=CAAT7ZBFIDtGIBAHds7o0RjZC8pxzkpfhqWI9n3iHZCQCjvoE4nPHCIZA03vuoicmhnZB9gZAnvcFZBcx9E0PJAcIM2BAWqcldZBhpxkpDV25pdUrJ6ieuPuZBHFM2OjEG5R2A49YBfVMUBOYeMmC5cDm5MUPRBTQQHS1ZA8LaTvuRfOVOL3jNRWECxh41m3mVHaaUZD&friend=100002749468179&me=100000206949854")
  kit.to_file('file.jpg')
end