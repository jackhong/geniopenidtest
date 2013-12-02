require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require :default

$users = {}

OPENID_FIELDS = {
  google: ["http://axschema.org/contact/email", "http://axschema.org/namePerson/last"],
  geni: ['http://geni.net/projects', 'http://geni.net/slices', 'http://geni.net/user/urn', 'http://geni.net/user/prettyname']
}

Warden::OpenID.configure do |config|
  config.required_fields = OPENID_FIELDS[:geni]
  config.user_finder do |response|
    #fields = OpenID::SReg::Response.from_success_response(response)
    identity_url = response.identity_url
    fields = OpenID::AX::FetchResponse.from_success_response(response).data
    $users[identity_url] = fields
    identity_url
  end
end

helpers do
  def warden
    env['warden']
  end
end

get '/' do
  haml <<-'HAML'
%p#notice= flash[:notice]
%p#error= flash[:error]

- if warden.authenticated?
  %p
    Welcome #{warden.user}!
    %a(href='/signout') Sign out
  %hr
    - $users[warden.user] && $users[warden.user].each do |k, v|
      %p
        #{k}: #{v}
- else
  %form(action='/signin' method='post')
    %p
      %label
        OpenID:
        %input(type='text' name='openid_identifier' size=30 value='https://portal.geni.net/server/server.php')
      %input(type='submit' value='Connect')
  HAML
end

post '/signin' do
  warden.authenticate!
  flash[:notice] = 'You signed in'
  redirect '/'
end

get '/signout' do
  warden.logout(:default)
  flash[:notice] = 'You signed out'
  redirect '/'
end

post '/unauthenticated' do
  if openid = env['warden.options'][:openid]
    # OpenID authenticate success, but user is missing
    # (Warden::OpenID.user_finder returns nil)
    session[:identity_url] = openid[:response].identity_url
    name = "Authenticated user via #{session[:identity_url]}"
    fields = OpenID::SReg::Response.from_success_response(openid[:response])
    u = fields.data
    $users[session.delete(:identity_url)] = u
    u[:junk] = (1..100000).map { "bob" }
    warden.set_user u
    redirect '/'
  else
    # OpenID authenticate failure
    flash[:error] = warden.message
    redirect '/'
  end
end

get '/register' do
  haml <<-'HAML'
%form(action='/signup' method='post')
  %p
    %label
      Name:
      %input(type='text' name='name')
    %input(type='submit' value='Sign up')
  HAML
end

post '/signup' do
  if (name = params[:name]).empty?
    redirect '/register'
  else
    $users[session.delete(:identity_url)] = name
    warden.set_user name
    flash[:notice] = 'You signed up'
    redirect '/'
  end
end
