# TODO List:


What we have done so far . . . 

# [--] Go to https://proximity.gimbal.com/developer/transmitters 
# [--] Name first beacon Hy1, factory code: 7NBP-BY85C
# [--] Key to Lat: 37.785525, Lon: -122.397581
# [--] TURN ON BLUETOOTH




# [--] Add a rule at: https://proximity.gimbal.com/developer/rules/new




# [--] More analytics: plot trend, 
# [--] plot intervals (times between events), 
# [--] Add a "____ help(s)(ed) ____ _____" route so folks can discover and then 
#      prototype their own reminder texts . . . 

# [--] Consider ID key to int ne: String ('+17244489427' --> 17244489427)
# [--] Enable and Test broadcast to everyone
# [--] Enable and Test broadcast to dev's

# [--] Enable a way for parents to invite other parents
# [--] Think of a way for kids to interact in anonymous ways with other kids


###############################################################################
# Ruby Gem Core Requires  --  this first grouping is essential
#   (Deploy-to: Heroku Cedar Stack)
###############################################################################
require 'rubygems' if RUBY_VERSION < '1.9'

require 'sinatra/base'
 require 'erb'

require 'sinatra/graph'

require 'net/http'
require 'uri'
require 'json'

require 'pony'

###############################################################################
# Optional Requires (Not essential for base version)
###############################################################################
# require 'temporals'

# require 'ri_cal'   
# require 'tzinfo'

# If will be needed, Insert these into Gemfile:
# gem 'ri_cal'
# gem 'tzinfo'

# require 'yaml'


###############################################################################
#                 App Skeleton: General Implementation Comments
###############################################################################
#
# Here I do the 'Top-Level' Configuration, Options-Setting, etc.
#
# I enable static, logging, and sessions as Sinatra config. options
# (See http://www.sinatrarb.com/configuration.html re: enable/set)
#
# I am going to use MongoDB to log events, so I also proceed to declare
# all Mongo collections as universal resources at this point to make them
# generally available throughout the app, encouraging a paradigm treating
# them as if they were hooks into a filesystem 
#
# Redis provides fast cache; SendGrid: email; Google API --> calendar access
# 
# I am also going to include the Twilio REST Client for SMS ops and phone ops,
# and so I configure that as well.  Neo4j is included for relationship 
# tracking and management.  
#
# Conventions: 
#   In the params[] hash, capitalized params are auto- or Twilio- generated
#   Lower-case params are ones that I put into the params[] hash via this code
#
###############################################################################

class TheApp < Sinatra::Base
  register Sinatra::Graph

  enable :static, :logging, :sessions
  set :public_folder, File.dirname(__FILE__) + '/static'

  configure :development do
    SITE = 'http://localhost:3000'
    puts '____________CONFIGURING FOR LOCAL SITE: ' + SITE + '____________'
  end
  configure :production do
    SITE = ENV['SITE']
    puts '____________CONFIGURING FOR REMOTE SITE: ' + SITE + '____________'
  end

  configure do
    begin
      PTS_FOR_BG = 10
      PTS_FOR_INS = 5
      PTS_FOR_CARB = 5
      PTS_FOR_LANTUS = 20
      PTS_BONUS_FOR_LABELS = 5
      PTS_BONUS_FOR_TIMING = 10

      DEFAULT_POINTS = 2
      DEFAULT_SCORE = 0 
      DEFAULT_GOAL = 500.0
      DEFAULT_PANIC = 24
      DEFAULT_HI = 300.0
      DEFAULT_LO = 70.0

      ONE_HOUR = 60.0 * 60.0
      ONE_DAY = 24.0 * ONE_HOUR
      ONE_WEEK = 7.0 * ONE_DAY

      puts '[OK!] [1]  Constants Initialized'
    end


    if ENV['TWITTER_CONSUMER_KEY'] && ENV['TWITTER_CONSUMER_SECRET'] && \
       ENV['TWITTER_ACCESS_TOKEN'] && ENV['TWITTER_ACCESS_TOKEN_SECRET']

      begin
        require 'twitter'
        require 'oauth'

        consumer = OAuth::Consumer.new(ENV['TWITTER_CONSUMER_KEY'],
                                       ENV['TWITTER_CONSUMER_SECRET'],
                                       { :site => "http://api.twitter.com",
                                         :scheme => :header })
        token_hash = {:oauth_token => ENV['TWITTER_ACCESS_TOKEN'],
                      :oauth_token_secret => ENV['TWITTER_ACCESS_TOKEN_SECRET']}
        
        $twitter_handle = OAuth::AccessToken.from_hash(consumer, token_hash )
        puts '[OK!] [2]  Twitter Client Configured'
      rescue Exception => e; puts "[BAD] Twitter config: #{e.message}"; end
    end

    if ENV['NEO4J_URL']
      begin
        note = 'NEO4j CONFIG via ENV var set via heroku addons:add neo4j'
        require 'neography'

        neo4j_uri = URI ( ENV['NEO4J_URL'] )
        $neo = Neography::Rest.new(neo4j_uri.to_s)

        http = Net::HTTP.new(neo4j_uri.host, neo4j_uri.port)
        verification_req = Net::HTTP::Get.new(neo4j_uri.request_uri)
        
        if neo4j_uri.user
          verification_req.basic_auth(neo4j_uri.user, neo4j_uri.password)
        end #if

        response = http.request(verification_req)
        abort "Neo4j down" if response.code != '200' 

        # console access via: heroku addons:open neo4j

        puts("[OK!] [3]  Neo #{neo4j_uri},:#{neo4j_uri.user}:#{neo4j_uri.password}")
      rescue Exception => e;  puts "[BAD] Neo4j config: #{e.message}";  end
    end

    if ENV['MONGODB_URI']
      begin
        require 'mongo'
        require 'bson'    #Do NOT 'require bson_ext' just put it in Gemfile!

        CN = Mongo::Connection.new
        DB = CN.db

        puts("[OK!] [4]  Mongo Configured-via-URI #{CN.host_port} #{CN.auths}")
      rescue Exception => e;  puts "[BAD] Mongo config(1): #{e.message}";  end
    end

    if ENV['MONGO_URL'] and not ENV['MONGODB_URI']
      begin
        require 'mongo'
        require 'bson'    #Do NOT 'require bson_ext' just put it in Gemfile!
        
        CN = Mongo::Connection.new(ENV['MONGO_URL'], ENV['MONGO_PORT'])
        DB = CN.db(ENV['MONGO_DB_NAME'])
        auth = DB.authenticate(ENV['MONGO_USER_ID'], ENV['MONGO_PASSWORD'])

        puts('[OK!] [4]  Mongo Connection Configured via separated env vars')
      rescue Exception => e;  puts "[BAD] Mongo config(M): #{e.message}";  end
    end

    if ENV['REDISTOGO_URL']
      begin
        note = 'CONFIG via ENV var set via heroku addons:add redistogo'
        require 'hiredis'
        require 'redis'
        uri = URI.parse(ENV['REDISTOGO_URL'])
        REDIS = Redis.new(:host => uri.host, :port => uri.port,
                          :password => uri.password)
        REDIS.set('CacheStatus', "[OK!] [5]  Redis #{uri}")
        puts REDIS.get('CacheStatus')
      rescue Exception => e;  puts "[BAD] Redis config: #{e.message}";  end
    end

    if ENV['TWILIO_ACCOUNT_SID']&&ENV['TWILIO_AUTH_TOKEN']
      begin
        require 'twilio-ruby'
        require 'builder'
        $t_client = Twilio::REST::Client.new(
          ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'] )
        $twilio_account = $t_client.account
        puts '[OK!] [6]  Twilio Configured for: ' + ENV['TWILIO_CALLER_ID']
      rescue Exception => e;  puts "[BAD] Twilio config: #{e.message}";  end
    end

    # Store the calling route in GClient.authorization.state 
    # That way, if we have to redirect to authorize, we know how to get back
    # to where we left off...

    if ENV['GOOGLE_ID'] && ENV['GOOGLE_SECRET']
      begin
        require 'google/api_client'
        options = {:application_name => ENV['APP'],
                   :application_version => ENV['APP_BASE_VERSION']}
        GClient = Google::APIClient.new(options)
        GClient.authorization.client_id = ENV['GOOGLE_ID']
        GClient.authorization.client_secret = ENV['GOOGLE_SECRET']
        GClient.authorization.redirect_uri = SITE + 'oauth2callback'
        GClient.authorization.scope = [ 
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/tasks'
        ]
        GClient.authorization.state = 'configuration'

        RedirectURL = GClient.authorization.authorization_uri.to_s
        GCal = GClient.discovered_api('calendar', 'v3')

        puts '[OK!] [7]  Google API Configured with Scope Including:'
        puts GClient.authorization.scope

      rescue Exception => e;  puts "[BAD] GoogleAPI config: #{e.message}";  end
    end

    if ENV['SENDGRID_USERNAME'] && ENV['SENDGRID_PASSWORD']
      begin
        Pony.options = {
          :via => :smtp,
          :via_options => {
          :address => 'smtp.sendgrid.net',
          :port => '587',
          :domain => 'heroku.com',
          :user_name => ENV['SENDGRID_USERNAME'],
          :password => ENV['SENDGRID_PASSWORD'],
          :authentication => :plain,
          :enable_starttls_auto => true
          }
        }
        puts "[OK!] [8]  SendGrid Options Configured"
      rescue Exception => e;  puts "[BAD] SendGrid config: #{e.message}";  end
    end

  end #configure



  #############################################################################
  #                             Sample Analytics
  #############################################################################
  #
  # Plot everyone's BG values in the db so far. 
  # 
  # PLEASE NOTE: This route is Illustrative-Only; not meant
  # to scale . . . 
  #
  #############################################################################
 

  # For Example, to view this graph, nav to: 
  #  http://pacific-ridge-7904.herokuapp.com/plot/bloodglucose.svg
 
  graph "bloodglucose", :prefix => '/plot' do
    cursor = DB['checkins'].find({'mg' => {'$exists' => true}})
    bg_a = Array.new
    cursor.each{ |d|
      bg_a.push(d['mg'])
    }
    bar "mg/dL", bg_a
  end

  #  http://pacific-ridge-7904.herokuapp.com/plot/history.svg
  graph "history", :prefix => '/plot' do
    puts who = params['From'].to_s
    puts '  (' + who.class.to_s + ')'
    puts flavor = params['flavor']

    search_clause = { flavor => {'$exists' => true}, 'ID' => params['From'] }

    count = DB['checkins'].find(search_clause).count 
    num_to_skip = (count > 20 ? count-20 : 0)

    cursor = DB['checkins'].find(search_clause).skip(num_to_skip)
    bg_a = Array.new
    cursor.each{ |d|
      bg_a.push(d[flavor])
    }
    line flavor, bg_a
  end


  #############################################################################
  #                            Routing Code Filters
  #############################################################################
  #
  # It's generally safer to use custom helpers explicitly in each route. 
  # (Rather than overuse the default before and after filters. . .)
  #
  # This is especially true since there are many different kinds of routing
  # ops going on: Twilio routes, web routes, etc. and assumptions that are
  # valid for one type of route may be invalid for others . . .  
  #
  # So in the "before" filter, we just print diagnostics & set a timetamp
  # It is worth noting that @var's changed or set in the before filter are
  # available in the routes . . .  
  #
  # A stub for the "after" filter is also included
  # The after filter could possibly also be used to do command bifurcation
  #
  # Before every route, print route diagnostics & set the timetamp
  # Look up user in db.  If not in db, insert them with default params.
  # This will ensure that at least default data will be available for every
  # user, even brand-new ones.  If someone IS brand-new, send disclaimer.
  #
  #############################################################################
  before do
    puts where = 'BEFORE FILTER'
    begin
      print_diagnostics_on_route_entry
      @these_variables_will_be_available_in_all_routes = true
      @now_f = Time.now.to_f

    if params['From'] != nil
      @this_user = DB['people'].find_one('_id' => params['From'])

      if (@this_user == nil)
        onboard_a_brand_new_user 
        @this_user = DB['people'].find_one('_id' => params['From'])
      end #if

      puts @this_user
    end #if params

    rescue Exception => e;  log_exception( e, where );  end
  end

  after do
    puts where = 'AFTER FILTER'
    begin

    rescue Exception => e;  log_exception( e, where );  end
  end


  #############################################################################
  #                            Routing Code Notes
  #############################################################################
  # Some routes must "write" TwiML, which can be done in a number of ways.
  #
  # The cleanest-looking way is via erb, and Builder and raw XML in-line are
  # also options that have their uses.  Please note that these cannot be
  # readily combined -- if there is Builder XML in a route with erb at the
  # end, the erb will take precedence and the earlier functionality is voided
  #
  # In the case of TwiML erb, my convention is to list all of the instance
  # variables referenced in the erb directly before the erb call... this
  # serves as a sort of "parameter list" for the erb that is visible from
  # within the routing code
  #############################################################################

  get '/test' do
    'Server is up! '  
  end

  get '/gimbal' do
    send_SMS_to( '+17244489427', 'That thing with the gimbal happened' )
  end

  get '/gimbal_hot' do
    send_SMS_to( '+17244489427', 'Ouch!  Too hot!' )
  end

  get '/gimbal_abandon' do
    send_SMS_to( '+17244489427', 'Babysitter seems to be away from baby' )
  end




  post '/send_SMS_to_Steve' do
    send_SMS_to( '+17244489427', 'Test number 2 from Deep' )
  end 

  get '/DeepsReplySMS' do 
    reply_via_SMS( 'This is your reply' ) 
  end  

  get '/DeepsSMSsend' do
    puts number = params['To']
    puts "BAD PHONE NUMBER" if number.match(/\+1\d{10}\z/)==nil

    puts msg = params['What']

    send_SMS_to( params['To'], params['What'] )
  end

  post '/DeepsSMSsend' do
    puts number = params['To']
    puts "BAD PHONE NUMBER" if number.match(/\+1\d{10}\z/)==nil

    puts msg = params['What']

    send_SMS_to( params['To'], params['What'] )
  end

  # Look how easy Redis is to use. . . 

  # Let's give whatever we receive in the params to REDIS.set
  get '/redisify' do
    puts 'setting: ' + params['key']
    puts 'to: ' + params['value']
    REDIS.set(params['key'], params['value'])
  end

  # REDIS.get fetches it back. . . 
  get '/getfromredis' do
    puts @value = REDIS.get(params['key'])
  end


  #############################################################################
  #                     Physical Environemnt Sensing
  #############################################################################
  #
  # Our sensor can detect vibration, magnetic proximity and/or moisture
  #
  #############################################################################

  get '/magswitch_is_opened' do
    puts where = "MAGNETIC SWITCH SENSOR OPENING ROUTE"
    the_time_now = Time.now

    event = {
      'ID' => '+17244489427', 
      'utc' => the_time_now.to_f,
      'flavor' => 'fridge', 
      'fridge' => 1.0, 
      'value_s' => '1.0', 
      'Who' => 'ZergLoaf BlueMeat',
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'Where' => where,
      'What' => 'Door Magnet Sensor on Pauls fridge opened',
      'Why' => 'Fridge main door opening'
    }
    puts DB['checkins'].insert( event, {:w => 1} )
  end


  get '/magswitch_is_closed' do

  end



  # Vibration sensor currently set at 63 milli-g sensitivity for freezer door

  get '/vibration_sensor_starts_shaking' do
    puts where = "VIBRATION SENSOR STARTS SHAKING ROUTE"
    the_time_now = Time.now

    event = {
      'ID' => '+17244489427', 
      'utc' => the_time_now.to_f,
      'flavor' => 'fridge', 
      'fridge' => 1.0, 
      'value_s' => '1.0', 
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'Who' => 'ZergLoaf BlueMeat',
      'Where' => where, 
      'What' => 'Vibration Sensor on top of Pauls fridge moved', 
      'Why' => 'Possible freezer door opening'
    }

    puts DB['checkins'].insert( event, {:w => 1} )

  end


  get '/vibration_sensor_stops_shaking' do
    puts "VIBRATION SENSOR STOPS SHAKING ROUTE"

  end




  #############################################################################
  # Voice Route to handle incoming phone call
  #############################################################################
  # Handle an incoming voice-call via TwiML
  #
  #  At the moment this has two main use cases:
  #  [1] Allow a patient to verify their last check in
  #  [2] Avoid worry by making the last time and reading available to family
  #
  #  Accordingly, first we look up the phone number to see who is calling
  #   If they have a patient in the system, we play info for that patient
  #   If they are a patient and have data we speak their last report
  #
  #############################################################################
  get '/voice_request' do
    puts "VOICE REQUEST ROUTE"

    patient_ph_num = patient_ph_num_assoc_wi_caller
    # last_level = last_glucose_lvl_for(patient_ph_num)
    last_level = last_checkin_for(patient_ph_num)

    if (last_level == nil)
      @flavor_text = 'you'
      @number_as_string = 'never '
      @time_of_last_checkin = 'texted in.'
    else
      @number_as_string = last_level['value_s']
      @flavor_text = last_level['flavor']
      interval_in_hours = (Time.now.to_f - last_level['utc']) / ONE_HOUR
      @time_of_last_checkin = speakable_hour_interval_for( interval_in_hours )
    end #if

    speech_text = 'Hi! The last checkin for'
    speech_text += ' ' 
    speech_text += @flavor_text 
    speech_text += ' ' 
    speech_text += 'was' 
    speech_text += ' ' 
    speech_text += @number_as_string
    speech_text += ' ' 
    speech_text += @time_of_last_checkin
   
    response = Twilio::TwiML::Response.new do |r|
      r.Pause :length => 1
      r.Say speech_text, :voice => 'woman'
      r.Pause :length => 1
      r.Hangup
    end #do response

    response.text do |format|
      format.xml { render :xml => response.text }
    end #do response.text
  end #do get



  #############################################################################
  # EXTERNALLY-TRIGGERED EVENT AND ALARM ROUTES
  #############################################################################
  #
  # Whenever we are to check for alarm triggering, someone will 'ping' us,
  # activating one of the following routes. . .
  #
  # Every ten minutes, check to see if we need to text anybody.
  # We do this by polling the 'textbacks' collection for msgs over 12 min old
  # If we need to send SMS, send them the text and remove the textback request
  #
  #############################################################################

  get '/ten_minute_heartbeat' do
    puts where = 'HEARTBEAT'

    begin
      REDIS.incr('Heartbeats')

      cursor = DB['textbacks'].find()
      cursor.each { |r|
        if ( Time.now.to_f > (60.0 * 12.0 + r['utc']) )
          send_SMS_to( r['ID'], r['msg'] )
          DB['textbacks'].remove({'ID' => r['ID']})
        end #if
      }
    
      h = REDIS.get('Heartbeats')
      puts ".................HEARTBEAT #{h} COMPLETE.........................."

    rescue Exception => e
      msg = 'Could not complete ten minute heartbeat'
      log_exception( e, where )
    end

    Time.now.to_s  # <-- Must return a string for all get req's

  end #do tick


  get '/hourly_ping' do
    puts where = 'HOURLY PING'
    a = Array.new

    begin
      REDIS.incr('HoursOfUptime')

      #DO HOURLY CHECKS HERE

      h = REDIS.get('HoursOfUptime')
      puts "------------------HOURLY PING #{h} COMPLETE ----------------------"

    rescue Exception => e
      msg = 'Could not complete hourly ping'
      log_exception( e, where )
    end

    "One Hour Passes"+a.to_s  # <-- Must return a string for all get req's

  end #do get ping


  get '/daily_refresh' do
    puts where = 'DAILY REFRESH'
    a = Array.new

    begin
     REDIS.incr('DaysOfUptime')

     #DO DAILY UPKEEP TASKS HERE

      d = REDIS.get('DaysOfUptime')
      puts "==================DAILY REFRESH #{d} COMPLETE ===================="

    rescue Exception => e
      msg = 'Could not complete daily refresh'
      log_exception( e, where )
    end

    "One Day Passes"+a.to_s  # <-- Must return a string for all get req's

  end



  #############################################################################
  #                         Google API routes
  #
  # Auth-Per-Transaction example:
  #
  # https://code.google.com/p/google-api-ruby-client/
  #          source/browse/calendar/calendar.rb?repo=samples
  # https://code.google.com/p/google-api-ruby-client/wiki/OAuth2
  #
  # Refresh Token example:
  #
  # http://pastebin.com/cWjqw9A6
  #
  #
  #############################################################################

  get '/insert' do
    where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.state = request.path_info
      ensure_session_has_GoogleAPI_refresh_token_else_redirect()

      puts cursor = DB['sample'].find({'location' => 'TestLand' })

      insert_into_gcal_from_mongo( cursor )
      GClient.authorization.state = '*route completed*'
    rescue Exception => e;  log_exception( e, where ); end
  end


  get '/quick_add' do
    where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.state = request.path_info
      ensure_session_has_GoogleAPI_refresh_token_else_redirect()

      puts cursor = DB['sample'].find({'location' => 'TestLand' })

      quick_add_into_gcal_from_mongo( cursor )
      GClient.authorization.state = '*route completed*'
    rescue Exception => e;  log_exception( e, where ); end
  end


  get '/delete_all_APP_events' do
    where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.state = request.path_info
      ensure_session_has_GoogleAPI_refresh_token_else_redirect()

      page_token = nil

      result = GClient.execute(:api_method => GCal.events.list,
       :parameters => {'calendarId' => 'primary', 'q' => 'APP_gen_event'})
      events = result.data.items
      puts events

      events.each { |e|
        GClient.execute(:api_method => GCal.events.delete,
         :parameters => {'calendarId' => 'primary', 'eventId' => e.id})
        puts 'DELETED EVENT wi. ID=' + e.id
      }
    rescue Exception => e;  log_exception( e, where ); end

  end #delete all APP-generated events


  get '/list' do
    ensure_session_has_GoogleAPI_refresh_token_else_redirect()
    
    calendar = GClient.execute(:api_method => GCal.calendars.get,
                               :parameters => {'calendarId' => 'primary' })

    print JSON.parse( calendar.body )
    return calendar.body
  end


  # Request authorization
  get '/oauth2authorize' do
    where = 'ROUTE PATH: ' + request.path_info
    begin

      redirect user_credentials.authorization_uri.to_s, 303
    rescue Exception => e;  log_exception( e, where ); end
  end

  get '/oauth2callback' do
    where = 'ROUTE PATH: ' + request.path_info
    begin
      GClient.authorization.code = params[:code]
      results = GClient.authorization.fetch_access_token!
      session[:refresh_token] = results['refresh_token']
      redirect GClient.authorization.state
    rescue Exception => e;  log_exception( e, where ); end
  end



  #############################################################################
  # SMS_request (via Twilio) 
  #############################################################################
  #
  # SMS routing essentially follows a command-line interface interaction model
  #
  # I get the SMS body, sender, and intended recipient (the intended recipient
  # should obviously be this app's own phone number).
  #
  # I first archive the SMS message in the db, regardless of what else is done
  #
  # I then use the command as a route in this app, prefixed by '/c/'
  #
  # At this point, I could just feed the content to the routes... that's a bit
  # dangerous, security-wise, though... so I will prepend with 'c' to keep
  # arbitrary interactions from routing right into the internals of the app!
  #
  # So, all-in-all: add protective wrapper, downcase the message content,
  # remove all of the whitespace from the content, . . .
  # and then prepend with the security tag and forward to the routing
  #
  #############################################################################
  get '/SMS_request' do
    puts where = 'SMS REQUEST ROUTE'
    begin

    the_time_now = Time.now

    puts info_about_this_SMS_to_log_in_db = {
      'Who' => params['From'],
      'utc' => the_time_now.to_f,
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p"),
      'What' => params['Body']
    }
    puts DB['log'].insert(info_about_this_SMS_to_log_in_db, {:w => 1 })

    # w == 1 means SAFE == TRUE
    # can specify at the collection level, op level, and init level

    c_handler = '/c/'+(params['Body']).downcase.gsub(/\s+/, "")

    puts "SINATRA: Will try to use c_handler = "+c_handler
    redirect to(c_handler)

    rescue Exception => e;  log_exception( e, where ); end
  end #do get




  #############################################################################
  # Command routes are defined by their separators
  # Command routes are downcased before they come here, in SMS_request
  #
  # Un-caught routes fall through to default routing
  #
  # Roughly, detect all specific commands first
  # Then, detect more complex phrases
  # Then, detect numerical reporting
  # Finally, fall through to the default route
  # Exceptions can occur in: numerical matching
  # So, there must also be an exception route...
  #############################################################################
  get '/c/' do 
    puts "BLANK SMS ROUTE"
    send_SMS_to( params['From'], 'Received blank SMS, . . .  ?' )
  end #do get

  get '/c/hello*' do
    puts "GREETINGS ROUTE"
    send_SMS_to( params['From'], 'Hello, and Welcome!' )
  end #do get


  #############################################################################
  # User Generated Plots
  #############################################################################
  get /\/c\/plot[:,\s]*(?<flavor>\w+)[:,\s]*/ix do 
    flavor = params[:captures][0]
    link = SITE + 'plot/history.svg'
    link += '?' 
    link += 'From=' + CGI::escape( params['From'] )
    link += '&'
    link += 'flavor=' + CGI::escape( flavor.downcase )

    msg = "Link to your plot: " + link
    send_SMS_to( params['From'], msg )
  end #do get


  #############################################################################
  # User Generated Observations
  #############################################################################
  get /\/c\/(?<act>\S+)[\s]*help(s|ed)[\s]*(?<x>\w+)[\s]*(?<where>@\w+)?/ix do
    act = params[:captures][0]
    x = params[:captures][1]
    where = params[:captures][2] ? params[:captures][2].gsub('@','') :'unknown'

    msg = 'Great! We\'ll remember that was helpful, to remind you later...  '
    send_SMS_to( params['From'], msg )
   
    the_time_now = Time.now
    event = {
      'ID' => params['From'], 
      'utc' => the_time_now.to_f,
      'trigger' => x,  
      'act' => act, 
      'Who' => params['From'],
      'Where' => where,
      'What' => act,
      'When' => the_time_now.strftime("%A %B %d at %I:%M %p")
    }
    puts DB['observations'].insert( event, {:w => 1} )
  end #do get


  #############################################################################
  # User Role Setting and Configuration Routes
  #############################################################################
  # Authorize from a patient's phone, to enable a caregiver to get updates.
  # We will use the to-be-Caller's(Caregiver's) number as the key to map
  # to the Patient's phone number, to look up the checkin history... 
  #
  # If we detect a leading '+' then we will +add+ what we expect to be 
  # a parent / guardian phone number to the auth list mapping...
  #
  # We sub out whitespace, parens, .'s and -'s from the entered phone number, 
  # so that (650) 324 - 5687 and 650-324-5687 and 650.324.5687 all work
  #
  # To insert into db, ensure 11 numerical digits, starting with a leading '+1'
  # Since we use auth key as the '_id' save will function as an upsert
  #
  # Question: what if multiple caregivers inserted?  
  #############################################################################
  get /\/c\/\+1?s*[-\.\(]?(\d{3})[-\.\)]*\s*(\d{3})\s*[\.-]*\s*?(\d{4})\z/x do
  puts where = "AUTHORIZE NEW CAREGIVER ROUTE"
  begin
    authorization_string = ''
    params[:captures].each {|match_group| authorization_string += match_group}
    authorization_string= '+1' + authorization_string

    if authorization_string.match(/\+1\d{10}\z/) == nil
      reply_via_SMS( 'Please text, for example: +6505555555 (to add that num)' )
    else
      doc = {
        '_id' => authorization_string, 
        'PatientID' => params['From'],
        'CaregiverID' => authorization_string,
        'utc' => @now_f
      }
      DB['groups'].save(doc) unless authorization_string == params['From']

      DB['people'].update({'_id' => params['From']}, 
                          {'$set' => {'active_patient' => 'yes'}}) 

      reply_via_SMS('You cannot register as your own parent!') if authorization_string == params['From']

      reply_via_SMS( 'You have authorized: ' + authorization_string )
      send_SMS_to( authorization_string, 'Authorized for: '+params['From'] )
    end #if

  rescue Exception => e
    msg = 'Could not complete authorization'
    reply_via_SMS( msg )
    log_exception( e, where )
  end

  end #do authorization


  get /\/c\/\-1?s*[-\.\(]?(\d{3})[-\.\)]*\s*(\d{3})\s*[\.-]*\s*?(\d{4})\z/x do
  puts where = "DE-AUTHORIZE A CAREGIVER ROUTE"
  begin    
    authorization_string = ''
    params[:captures].each {|match_group| authorization_string += match_group}
    authorization_string= '+1' + authorization_string

    if authorization_string.match(/\+1\d{10}\z/) == nil
      reply_via_SMS( 'Please text, for example: -6505555555' )
    else
      DB['groups'].remove({'CaregiverID' => authorization_string}) 

      reply_via_SMS( 'You have de-authorized: ' + authorization_string )
      send_SMS_to( authorization_string, 'De-Authorized for: '+params['From'] )
    end #if

  rescue Exception => e
    msg = 'Could not complete de-authorization'    
    reply_via_SMS( msg )
    log_exception( e, where )
  end

  end #do de-authorization



  #############################################################################
  # USER HELP MENU
  #############################################################################
  #
  # Decide if it's a patient or caregiver who is requesting help and then 
  # forward them the approp. content. . .  
  #
  #############################################################################
  get /\/c\/help/x do

    p_msg = 'HELP TOPICS: text Checkins, Config, or Feedback for info on each.'

    c_msg = 'info=see settings; low67=low BG threshold at 67; high310=high threshold at 310; goal120=set 7 day goal to 120 pts; week=check stats'

    msg = p_msg 
    msg = c_msg if DB['groups'].find_one({'CaregiverID' => params['From']})

    reply_via_SMS( msg )

  end # get help


  get /\/c\/(help)?checkins/x do
    msg_for_patient = 'bg123b = glucose 123 at breakfast; c20d = 20g carbs at dinner; n5L = 5U novolog at lunch; L4 = 4U lantus; score = see points'

    reply_via_SMS( msg_for_patient )
  end # Checkins help


  get /\/c\/(help)?config/x do
    msg_for_patient = 'alarm5 = set reminder at 5 hours; +16505551212 = add caregiver at that ph num; info = check settings'

    reply_via_SMS( msg_for_patient )
  end # Config help


  get /\/c\/(help)?feedback/x do
    msg_for_patient = 'Have unanswered questions or comments? Text/call 650-275-2901 and leave a message!'

    reply_via_SMS( msg_for_patient )
  end # Feedback help



  #############################################################################
  # Stop all msgs and take this user out of all of the collections
  # (If either patient or caregiver issues this command, dis-enroll BOTH)
  #############################################################################
  get /\/c\/stop/ do
  puts 'STOP ROUTE'

  begin
    DB['groups'].remove( {"CaregiverID"=>params['From']} )
    DB['groups'].remove( {"PatientID"=>params['From']} )
    DB['people'].remove( {"ID"=>params['From']} )
    msg = 'OK! -- stopping all interactions and dis-enrolling both parties'
    msg +=' (Re-register to re-activate)'
  rescue Exception => e
    msg = 'Could not stop scheduled texts'
    log_exception( e, 'STOP ROUTE' )
  end

    reply_via_SMS( msg )
  end #do resign


  #############################################################################
  # Delete all checkin data for this user in the system
  #############################################################################
  get /\/c\/delete/ do
  puts 'DELETE ROUTE'

  begin
    authorization_string = params['From']

    if authorization_string.match(/\+1\d{10}\z/) == nil
      msg = 'Phone Number should be of the form: +16505551234'
    else
      DB['checkins'].remove({'ID' => authorization_string})
      msg = 'Wiped out checkin history for: '+authorization_string
    end

  rescue Exception => e
    msg = 'Could not delete all checkins'
    log_exception( e, 'DELETE ROUTE' )
  end

    reply_via_SMS( msg )
  end #do reset


  #############################################################################
  # Remove a caregiver from the groups collection to stop notices to them
  #############################################################################
  get /\/c\/resign/ do
  puts 'CAREGIVER RESIGNATION ROUTE'
  begin
    DB['groups'].remove( {"CaregiverID"=>params['From']} )
    msg = 'Stopped your notifications. '
    msg += '(Type: ' + params['From'] + ' from patient phone to re-activate)'
  rescue Exception => e
    msg = 'Could not resign caregiver from updates'
    log_exception( e, 'CAREGIVER RESIGNATION ROUTE' )
  end
    reply_via_SMS( msg )
  end #do resign


  #############################################################################
  # Set a new goal and notify both patient and caregiver
  #############################################################################
  get /\/c\/goal[\s:\.,-=]*?(\d{2,4})\z/ do
  puts "GOAL SETTING ROUTE"
  begin
    goal_f = Float(params[:captures][0])
    ph_num = patient_ph_num_assoc_wi_caller
    doc = {
              'ID' => ph_num,
              'Who' => params['From'],
              'goal' => goal_f,
              'utc' => @now_f
    }
    DB['checkins'].insert(doc)
    msg = 'New 7-day goal of: ' + goal_f.to_s + ' -- Go for it!'

  rescue Exception => e
    msg = 'Could not update goal for '+ ph_num.to_s
    log_exception( e, 'GOAL SETTING ROUTE' )
  end

    reply_via_SMS( msg )
   
    ct_msg = 'New goal of: ' + goal_f.to_s 
    send_SMS_to( ph_num, ct_msg ) if ph_num != params['From']
  end # do goal


  #############################################################################
  # Routes enabling either patient or caregiver to change the various settings 
  #############################################################################
  get /\/c\/(hi)g?h?[\s:\.,-=]*(\d{3})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {key => new_f}})
    msg = 'New '+key.to_s+': ' + new_f.to_s + ' mg_per_dL'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'HI SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings

  get /\/c\/(lo)w?[\s:\.,-=]*(\d{2})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {key => new_f}})
    msg = 'New '+key.to_s+': ' + new_f.to_s + ' mg_per_dL'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'LO SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings

  get /\/c\/age[\s:\.,-=]*(\d{2})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {key => new_f}})
    msg = 'New '+key.to_s+': ' + new_f.to_s + ' years'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'AGE SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings

  get /\/c\/(alarm)[\s:\.,-=]*(\d{1})\z/ do
  begin
    key = params[:captures][0]
    puts "SETTINGS ROUTE FOR: " + key
    new_f = Float(params[:captures][1])

    ph_num = patient_ph_num_assoc_wi_caller
    record = DB['people'].find_one({'_id' => ph_num})
    id = record['_id']
    DB['people'].update({'_id' => id},
                        {"$set" => {'alarm' => new_f}})
    DB['people'].update({'_id' => id},
                        {"$set" => {'timer' => new_f}})
    msg = 'New alarm threshold: ' + new_f.to_s + ' hours.'

  rescue Exception => e
    msg = 'Could not update setting for '+key.to_s
    log_exception( e, 'ALARM SETTING ROUTE' )
  end

    send_SMS_to( ph_num, msg ) if ph_num != params['From']
    reply_via_SMS( msg )
  end #do hi settings



  #############################################################################
  # Status-checking Routes. . .  
  #############################################################################
  get '/c/info' do
    puts "INFO ROUTE"
    patient_ph_num = patient_ph_num_assoc_wi_caller
    info_s = info_for( patient_ph_num )
    reply_via_SMS( info_s )
  end #do get

  get '/c/score' do
    puts "SCORE REPORT ROUTE"
    patient_ph_num = patient_ph_num_assoc_wi_caller
    score_s = score_for( patient_ph_num )
    reply_via_SMS( score_s )
  end #do get

  get '/c/week*' do
    puts "WEEKLY REPORTING ROUTE"
    patient_ph_num = patient_ph_num_assoc_wi_caller
    summary = weekly_summary_for( patient_ph_num ) 
    reply_via_SMS(summary)
  end #do get

  get '/c/check' do
    puts "LAST CHECKIN ROUTE, CHECK-as-keyword"

    patient_ph_num = patient_ph_num_assoc_wi_caller
    last_level = last_glucose_lvl_for(patient_ph_num)

    msg = 'Glucose: '
    if (last_level == nil)
      msg += 'not yet reported (no checkins yet)'
      @number_as_string = 'not yet '
      @time_of_last_checkin = 'reported. '
    else
      @level = last_level['mg']
      interval_in_hours = (Time.now.to_f - last_level['utc']) / ONE_HOUR
      @time_of_last_checkin = speakable_hour_interval_for( interval_in_hours )
      msg += @level.to_s
      msg += ', '
      msg += @time_of_last_checkin
    end #if

    reply_via_SMS(msg)
  end #do get

  get '/c/last' do
    puts "LAST CHECKIN ROUTE"

    patient_ph_num = patient_ph_num_assoc_wi_caller
    last_level = last_glucose_lvl_for(patient_ph_num)

    msg = 'Glucose: '
    if (last_level == nil)
      msg += 'not yet reported (no checkins yet)'
      @number_as_string = 'not yet '
      @time_of_last_checkin = 'reported. '
    else
      @level = last_level['mg']
      interval_in_hours = (Time.now.to_f - last_level['utc']) / ONE_HOUR
      @time_of_last_checkin = speakable_hour_interval_for( interval_in_hours )
      msg += @level.to_s
      msg += ', '
      msg += @time_of_last_checkin
    end #if

    reply_via_SMS(msg)
  end #do get


  #############################################################################
  # Revise Check-In
  #############################################################################
  #
  # In case the user has made a typo and catches the error from the 
  # confirmation text, we supply a mechanism to correct the typo in the db
  #
  # Type "!123!" to revise the last checkin to read "123" instead of what
  # was orginally entered... 
  #
  # So if a user types '!123!' in an SMS, we keep the same tags, timestamp
  # etc. and just update the glucose lvl value to '123' 
  #
  #############################################################################
  get /\/c\/!(?<whole>\d{1,3})\.?(?<fraction>\d{0,9})?!/ do |whole,fraction|
    puts where = 'TYPO CORRECTION ROUTE'

    begin
      new_value = whole 

      if (fraction.length >= 1)
        new_value += '.'
        new_value += fraction
      end #if

      revise_last_checkin_to(new_value)

    rescue Exception => e
      reply_via_SMS('SMS not quite right for typo correction:'+params['Body'])
      log_exception(e, where)
    end

  end #do get


  #############################################################################
  # Receive pulse checkin (precision-regex method)
  #############################################################################
  get /\/c\/p(ulse)?[:,\s]*(?<is>\d{2,3})/ix do
    puts where = 'PULSE CHECKIN REGEX ROUTE'

    begin
      pulse_f = Float(params[:captures][0])

      handle_checkin(pulse_f, "pulse")

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a pulse checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do checkin


  #############################################################################
  # Receive fast-acting insulin checkin (precision-regex method)
  #############################################################################
  get /\/c\/(?<i>n|h)[,\s:]*(?<is>\d*\.?\d+)[,\s:\.]*(?<at>\D*)/ix do
    puts where = 'FAST-ACTING INSULIN CHECKIN REGEX ROUTE'
    
    begin
      insulin_type_s = params[:captures][0]
      amount_taken_s = params[:captures][1]
      when_taken_s = params[:captures][2]

      units_f = Float( amount_taken_s )
      handle_insulin_checkin( units_f, when_taken_s, insulin_type_s )

    rescue Exception => e
      reply_via_SMS('SMS not quite right for insulin checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do insulin checkin


  #############################################################################
  # Receive long-acting (overnight) insulin checkin (precision-regex method)
  #############################################################################
  get /\/c\/(?<i>l)[,\s:]*(?<is>\d*\.?\d+)[,\s:\.]*(?<at>\D*)/ix do
    puts where = 'LANTUS (LONG-ACTING INSULIN) CHECKIN REGEX ROUTE'
    
    begin
      puts insulin_type_s = params[:captures][0]
      puts amount_taken_s = params[:captures][1]
      puts when_taken_s = params[:captures][2]

      units_f = Float( amount_taken_s )
      handle_lantus_checkin( units_f, when_taken_s)

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a Lantus checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do insulin checkin


  #############################################################################
  # Receive blood sugar checkin (precision-regex method)
  #############################################################################
  get /\/c\/b?g?(lucose)?[:,\s]*(?<is>\d{2,3})[:,\s]*(?<at>\D*)\z/ix do
    puts where = 'BLOOD SUGAR CHECKIN REGEX ROUTE'

    begin
      blood_sugar_f = Float(params[:captures][0])
      checkpoint_s = params[:captures][1]

      # reset_alarm_timer_for( params['From'] )
      handle_glucose_checkin(blood_sugar_f, checkpoint_s)

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a bg checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do sugar checkin


  #############################################################################
  # Receive carb checkin (precision-regex method)
  #############################################################################
  get /\/c\/c(arb)?s?[,\s:]*(?<is>\d*\.?\d+)[,\s:\.]*(?<at>\D*)/ix do
    puts where = 'CARB CHECKIN REGEX ROUTE'

    begin
      amount_taken_s = params[:captures][0]
      when_taken_s = params[:captures][1]

      grams_f = Float( amount_taken_s )
      handle_carb_checkin( grams_f, when_taken_s )

    rescue Exception => e
      reply_via_SMS('SMS not quite right for a carb checkin:'+params['Body'])
      log_exception(e, where)
    end

  end #do carb checkin


  #############################################################################
  # Send email report . . . 
  #############################################################################
  get /(?<email_addy>[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4})/ix do
  puts where = 'GMAIL REGEX ROUTE'
  begin
    puts @email_to = params[:captures][0]
    puts @subject = 'CTSA TEST!' 


    register_email_in_db(@email_to)

    ph = patient_ph_num_assoc_wi_caller
    @data = DB['checkins'].find({'ID'=>ph}).limit(10)

    puts @words = "Last %d check-ins. . . \n" % @data.count
    
    @data.each { |hash|
      hash.delete('_id')
      hash.delete('ID')
      hash.delete('utc')
      @words += hash.inspect
      @words += "\n"
    }

    @body = @words

    Pony.mail(:to => @email_to, :via => :smtp, :via_options => {
      :address => 'smtp.gmail.com',
      :port => '587',
      :enable_starttls_auto => true,
      :user_name => ENV['APP_EMAIL_ADDY'],
      :password => ENV['APP_EMAIL_AUTH'],
      :authentication => :plain, # :plain, :login, :cram_md5, no auth by default
      :domain => "gmail.com",
    },
      :subject => @subject, :body => @body)

    reply_via_SMS('Email sent')

  rescue Exception => e
    reply_via_SMS('Gmail failed')
    log_exception(e, where)
  end

  end #do gmail


  #############################################################################
  # Final / "Trap" routes: 
  #
  # Also:  Of course, if we do not know what the user meant, we should tell 
  # them we could not understand their text message.  
  # 
  #############################################################################


  # Trap+log a string key + digits + tag checkins we didn't anticipate . . .

  get /\/c\/(?<flavor>\D+)[:,\s]*(?<value>\d*\.?\d+)[:,\s]*(?<tag>\S+)/ix do
    flavor_s = params[:captures][0]
    value_f = Float( params[:captures][1] )
    tag_s = params[:captures][2]

    handle_tagged_checkin(value_f, flavor_s, tag_s)
  end #do get

  # Trap+log a string key + float or digit checkins we didn't anticipate . . . 

  get /\/c\/(?<flavor>\D+)[:,\s]*(?<value>\d*\.?\d+)/ix do
    flavor_s = params[:captures][0]
    value_f = Float( params[:captures][1] )

    handle_checkin(value_f, flavor_s)
  end #do get



  get '/c/*' do |text|
    puts 'SMS CATCH-ALL ROUTE'
    reply_via_SMS('Sorry :/ I could not understand that. Maybe check your card or text the word HELP? Also for some commands the exact #of digits is the key')
    doc = {
      'Who' => params['From'],
      'What' => text, 
      'utc' => Time.now.to_f
    }
    DB['unrouted'].insert(doc)
  end #do get


  get '/*' do |text|
    puts 'UNIVERSAL CATCH-ALL FOR ALL UNROUTED USER GETs'
    doc = {
      'Who' => params['From'],
      'What' => text,
      'utc' => Time.now.to_f
    }
    DB['unexpected'].insert(doc)
  end #do get


  post '/*' do |text|
    puts 'UNIVERSAL CATCH-ALL FOR ALL UNROUTED USER POSTs'
    doc = {
      'Who' => params['From'],
      'What' => text,
      'utc' => Time.now.to_f
    }
    DB['unexpected'].insert(doc)
  end #do get

  #############################################################################
  #                  END OF THE ROUTING SECTION OF THE APP                    #
  #############################################################################



  #############################################################################
  # SMS Command routes are defined by their separators
  # Command routes are downcased before they come here, in SMS_request
  # Spaces are optional in SMS commands, and are removed before /c/ routing
  #
  # Un-caught routes fall through to default routing
  #
  # Roughly, detect all specific commands first
  # Then, detect more complex phrases
  # Then, detect numerical reporting
  # Finally, fall through to the default route
  # Exceptions can occur in: numerical matching
  # So, there must also be an exception route...
  #############################################################################



  #############################################################################
  # Helpers
  #############################################################################
  # Note: helpers are executed in the same context as routes and views
  # Note: helpers have the params[] hash available to them in this scope
  #       So, this gives us another option to send reply SMS, in addition
  #       to via-erb... etc.
  #
  # Primarily, I am using helpers as db-accessors and Twilio REST call
  # convenience functions.  Other uses include caller authenitcation or
  # caller blocking, and printing diagnostics, logging info, etc. 
  #
  #############################################################################
  helpers do

    ###########################################################################
    # Logging Helpers
    ###########################################################################
    def log_exception( e, where = 'unspecified' )
      here = "HELPER: " + (__method__).to_s 
      begin
        puts ' --> LOGGING AN EXCEPTION FROM: --> ' + where
        puts e.message
        puts e.backtrace.inspect

        current_time = Time.now
        doc = {
               'Who' => params['From'],
               'What' => e.message,
               'When' => current_time.strftime("%A %B %d at %I:%M %p"),
               'Where' => where,
               'Why' => request.url,
               'How' => e.backtrace,
               'utc' => current_time.to_f
        }
        DB['exceptions'].insert(doc)

      rescue Exception => e
        puts 'ERROR IN ERROR LOGGING HELPER'
        puts e.message
        puts e.backtrace.inspect
      end

    end #def log_exception

  end #helpers
  #############################################################################
  # END OF HELPERS
  #############################################################################



  #############################################################################
  # FALLBACKS AND CALLBACKS 
  #############################################################################

  #############################################################################
  # If voice_request route can't be reached or there is a runtime exception:
  #############################################################################
  get '/voice_fallback' do
    puts "VOICE FALLBACK ROUTE"
    response = Twilio::TwiML::Response.new do |r|
      r.Say 'Goodbye for now!'
    end #response

    response.text do |format|
      format.xml { render :xml => response.text }
    end #do
  end #get


  #############################################################################
  # If the SMS_request route can't be reached or there is a runtime exception
  #############################################################################
  get '/SMS_fallback' do
    puts where = 'SMS FALLBACK ROUTE'
    begin
      doc = Hash.new
      params.each { |key, val|
        puts ('KEY:'+key+'  VAL:'+val)
        doc[key.to_s] = val.to_s
      }
      doc['utc'] = Time.now.to_f

      if ( env['sinatra.error'] == nil )
        puts 'NO SINATRA ERROR MESSAGE'
        doc['sinatra.error'] = 'None'
      else
        puts 'SINATRA ERROR \n WITH MESSAGE= ' + env['sinatra.error'].message
        doc['sinatra.error'] = env['sinatra.error'].message
      end

      DB['fallbacks'].insert(doc)

    rescue Exception => e;  log_exception( e, where );  end

  end #get


  #############################################################################
  # Whenever a voice interaction completes:
  #############################################################################
  get '/status_callback' do
    begin
      puts where = "STATUS CALLBACK ROUTE"

      puts doc = {
         'What' => 'Voice Call completed',
         'Who' => params['From'],
         'utc' => @now_f
      }
      puts DB['log'].insert(doc)

    rescue Exception => e;  log_exception( e, where );  end
  end #get


end #class TheApp
###############################################################################
# END OF TheAPP
###############################################################################


###############################################################################
# Further files . . .  (a.k.a. INCLUDE THE HELPERS)
# Include the helpers refernced by the below require_relative, 
# assuming those files-to-include feature the '.rb' extension . . . 
###############################################################################
require_relative 'HelpersForTheApp'
 

###############################################################################
# Helper modules included from files are available in routes but not in config
###############################################################################




###############################################################################
# END OF Code
###############################################################################








###############################################################################
#                          Things to Keep in Mind
###############################################################################
#
# !: Google API scope can be a string or an array of strings
#
# !: If some but not all scopes are authorized, unauthed routes fail silently
#
# !: To list & revoke G-API: https://accounts.google.com/IssuedAuthSubTokens
#
# !: Keep in mind where the "/" is!!!  #{SITE} includes one already...
#
# !: When it's dialing OUT, the App's ph num appears as params['From'] !
#
# !: cURL does not handle Sinatra redirects - test only 1 level deep wi Curl!
#
# !: Curious fact: In local mode, Port num does not appear, triggering rescue.
#
# +: An excellent Reg-Ex tool can be found here:   http://rubular.com
#
# +: Capped collections store documents with natural order(disk order) equal
#     to insertion order
#
# +: Capped collections also have an  automatic expiry policy (roll-over)
#
# -: Capped collections are fast to write to, but cannot handle remove
#     operations or update operations that increase the size of the doc
#
# ?: http://redis.io/topics/memory-optimization
# 
# !: http://support.redistogo.com/kb/heroku/redis-to-go-on-heroku
#
# ?: logging options: https://addons.heroku.com/#logging
#
# *: To get a Mongo Shell on the MongoHQ instance: 
# /Mongo/mongodb-osx-x86_64-2.2.2/bin/mongo --host $MONGO_URL --port $MONGO_PORT -u $MONGO_USER_ID -p $MONGO_PASSWORD   $MONGO_DB_NAME
#
# http://net.tutsplus.com/tutorials/tools-and-tips/how-to-work-with-github-and-multiple-accounts/
# http://stackoverflow.com/questions/13103083/how-do-i-push-to-github-under-a-different-username
# http://stackoverflow.com/questions/3696938/git-how-do-you-commit-code-as-a-different-user
# http://stackoverflow.com/questions/15199262/managing-multiple-github-accounts-from-one-computer
# https://heroku-scheduler.herokuapp.com/dashboard
#
# http://stackoverflow.com/questions/10407638/how-do-i-pass-a-ruby-array-to-javascript-to-make-a-line-graph
# http://blog.crowdint.com/2011/03/31/make-your-sinatra-more-restful.html
# http://stackoverflow.com/questions/5015471/using-sinatra-for-larger-projects-via-multiple-files
###############################################################################


 #############################################################################
 #                                                                           #
 #                           OPEN SOURCE LICENSE                             #
 #                                                                           #
 #             Copyright (C) 2011-2013  Dr. Stephen A. Racunas               #
 #                                                                           #
 #                                                                           #
 #   Permission is hereby granted, free of charge, to any person obtaining   #
 #   a copy of this software and associated documentation files (the         #
 #   "Software"), to deal in the Software without restriction, including     #
 #   without limitation the rights to use, copy, modify, merge, publish,     #
 #   distribute, sublicense, and/or sell copies of the Software, and to      #
 #   permit persons to whom the Software is furnished to do so, subject to   # 
 #   the following conditions:                                               #
 #                                                                           #
 #   The above copyright notice and this permission notice shall be          #
 #   included in all copies or substantial portions of the Software.         #
 #                                                                           #
 #                                                                           #
 #   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         #
 #   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      #
 #   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  #
 #   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    # 
 #   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    #
 #   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       # 
 #   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  #
 #                                                                           #
 #############################################################################


