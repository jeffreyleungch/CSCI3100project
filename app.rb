require 'sinatra'

set :host_authorization, { permitted_hosts: [] }  
class MyApp < Sinatra::Base
  get '/' do
    "<!DOCTYPE html><html><head></head><body><h1>Hello World</h1></body></html>"
  end
end