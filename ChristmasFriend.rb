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
#disable :protection

#after do
 # response.headers['X-Frame-Options'] = 'ALLOW-FROM apps.facebook.com' 
 # response.headers({ 'X-Frame-Options' => 'ALLOW-FROM apps.facebook.com' })
#end

configure do
  set :redirect_uri, nil
end



BASE_URL = "https://xmasfriend.herokuapp.com"
APP_URL = "https://xmasfriend.herokuapp.com"
#APP_URL = "https://apps.facebook.com/1402943853278306"

@no_footer = false
OmniAuth.config.on_failure = lambda do |env|
  [302, {'Location' => '/auth/failure', 'Content-Type' => 'text/html'}, []]
end

#---------------App configurations---------------
APP_ID = "795048987178429"
APP_SECRET = "001c7f7de5838811796f4d4d3fdcf442"
#------------------------------------------------

use OmniAuth::Builder do
  provider :facebook, APP_ID, APP_SECRET, { :scope => 'email, status_update, publish_stream,user_birthday,friends_birthday' }
end

def verify
redirect '/login' if session['fb_token'].nil?
end


get '/about' do
  erb :about
end



get '/post' do
   verify
  friend = session['friend']
   graph = Koala::Facebook::API.new(session['fb_token'])
    @profile = graph.get_object("me")
    @profile["image"] = graph.get_picture(@profile["id"],:type => "large")
    @friend = graph.get_object(friend)
    @friend["image"] = graph.get_picture(@friend["id"],:type => "large")
    @no_footer = true
    file = "post_pic/#{@profile["id"]}.jpg"
    	kit = IMGKit.new(erb :post, quality: 100)
	kit.to_file(file)
        image = graph.put_picture(file,  {:message => "#{@friend["first_name"]} #{@friend["last_name"]} is my christmas friend. \n Click #{APP_URL} to find your christmas friend"})
        graph.put_connections(image["id"], 'tags', {"to" => @friend["id"]})
	clear_session
	#delete_poster file
        @no_footer = false
    erb :about
end 

def delete_poster file
	File.delete(file) if File.exist?(file)
end


#--------------Find your friend page------------
get '/friend' do
  verify	
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
      if @profile['gender']=="male" && friend['gender']=="female" 	
	friend_dob = Date.strptime friend["birthday"], '%m/%d/%Y'
        if friend_dob.year <= my_dob.year+5 && friend_dob.year >= my_dob.year-2
   		suggestion << friend
        end      
      elsif @profile['gender']=="female"
	friend_dob = Date.strptime friend["birthday"], '%m/%d/%Y'
        if friend_dob.year <= my_dob.year+5 && friend_dob.year >= my_dob.year-5
 		suggestion << friend
        end      
     end
    rescue Exception => e
      puts e.message
    end
  end
  @friend = suggestion[Random.rand(suggestion.count)]
  @friend = graph.get_object(@friend['id'])
  @friend["image"] = graph.get_picture(@friend["id"],:type => "large")
  session['friend'] = @friend['id']
  puts @friend.inspect
  erb :friend
end   

#-----------------Home page ---------------------------------- 
get_post '/' do
	
  if session['fb_token']
    graph = Koala::Facebook::API.new(session['fb_token'])
    @profile = graph.get_object("me")
    @profile["image"] = graph.get_picture(@profile["id"],:type => "large")
  #  else
 #  redirect '/login'
 end
	  erb :index
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
  settings.redirect_uri = 'https://apps.facebook.com/xmasfriend/'

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
