
  module HelpersForTheApp

    ###########################################################################
    # SECTION: Generic Sinatra Helpers
    ###########################################################################

    ###########################################################################
    # Define a handler for multiple http verbs at once (can be convenient!)
    ###########################################################################
    def any(url, verbs = %w(get post put delete), &block)
      verbs.each do |verb|
        send(verb, url, &block)
      end
    end


    ###########################################################################
    # Helper: Print Route Info Upon Entry (usu. called from the before filter) 
    ###########################################################################
    def print_diagnostics_on_route_entry
      # for the full url: puts request.url
      # for printing part of the url: puts request.fullpath
      # for printing just the path info: puts request.path_info

      puts 'TRYING ROUTE: '+ request.path_info 
      puts ' WITH PARAMS HASH:'
      params.each { |k, v| 
        puts request.path_info + ': ' + k.to_s + ' <---> ' + v.to_s
      }
    end #def


    ###########################################################################
    # SECTION: Google API Helpers
    ###########################################################################

    ###########################################################################
    # Helper: Google API Refresh Token
    ###########################################################################
    def ensure_session_has_GoogleAPI_refresh_token_else_redirect()
      where = 'HELPER: ' + (__method__).to_s 
      begin
        redirect RedirectURL unless session[:refresh_token] 
        redirect RedirectURL if session[:refresh_token].length <= 3

        GClient.authorization.refresh_token = session[:refresh_token]
        GClient.authorization.fetch_access_token!
      rescue Exception => e;  log_exception( e, where ); end
    end #ensure_session_has_GoogleAPI_refresh_token_else_redirect()


    ###########################################################################
    # Helper: Google Calendar API Single-Event Insert
    ###########################################################################
    def insert_into_gcal( j )
      where = 'HELPER: ' + (__method__).to_s
      begin
        result = GClient.execute(:api_method => GCal.events.insert,
         :parameters => {'calendarId' => 'primary'},
         :body => JSON.dump( j ),
         :headers => {'Content-Type' => 'application/json'})
        puts "INSERTED event with id:" + result.data.id

        return result
      rescue Exception => e;  log_exception( e, where ); end
    end #insert_calendar_event


    ###########################################################################
    # Helper: Google Calendar API Multi-Event Insert from Mongo Cursor
    ###########################################################################
    def insert_into_gcal_from_mongo( cursor )
      where = 'HELPER: ' + (__method__).to_s
      begin
        cursor.each { |event|
          result = GClient.execute(:api_method => GCal.events.insert,
           :parameters => {'calendarId' => 'primary'},
           :body_object => event,
           :headers => {'Content-Type' => 'application/json'})
          puts "INSERTED event with result data id:" + result.data.id
        }
      rescue Exception => e;  log_exception( e, where ); end
    end #insert_calendar_event


    ###########################################################################
    # Helper: Google Calendar API Multi-Event Insert from Mongo Cursor
    ###########################################################################
    def insert_bg_checkins_into_gcal_from_mongo( cursor )
      where = 'HELPER: ' + (__method__).to_s
      begin
        cursor = DB['checkins'].find({'mg' => {'$exists' => true} })
        cursor.each { |checkin|
        event = Hash.new
        event['summary'] = (checkin['mg']).to_s
        event['color'] = Float(checkin['mg']) < 70 ?  2 : 3
        event['start']['dateTime'] = Time.at(checkin['utc']).strftime("%FT%T%z")
        event['start']['timeZone'] = 'America/Los_Angeles'
        event['end']['dateTime'] = Time.at(checkin['utc']+9).strftime("%FT%T%z")
        event['end']['timeZone'] = 'America/Los_Angeles'

        result = GClient.execute(:api_method => GCal.events.insert,
         :parameters => {'calendarId' => 'primary'},
         :body_object => event,
         :headers => {'Content-Type' => 'application/json'})
        puts "INSERTED event with result data id:" + result.data.id
        }
      rescue Exception => e;  log_exception( e, where ); end
    end #insert_calendar_event


    ###########################################################################
    # SECTION: Speakbles
    ###########################################################################

    ###########################################################################
    # Helper: Speakble Time (usage: speakable_time_for( Time.now )
    ###########################################################################
    def speakable_time_for( time )
      return time.strftime("%A %B %d at %I:%M %p")
    end #def

    ###########################################################################
    # Helper: Speakable Time Interval given float (and optional preamble)
    ###########################################################################
    def speakable_hour_interval_for( preamble=' ', float_representing_hours )
      where = 'HELPER: ' + (__method__).to_s
      begin
        msg_start = preamble

        whole_hours_i = float_representing_hours.to_i

        msg_start += whole_hours_i.to_s unless whole_hours_i==0

        h_f = float_representing_hours.floor
        h = float_representing_hours - h_f

        msg_mid = if    (h_f<=0)&&(h <= 0.2) then ' just a little while'
                  elsif (h_f<=0)&&(h <= 0.4) then ' a quarter hour'
                  elsif (h_f<=0)&&(h <= 0.6) then ' a half hour'
                  elsif (h_f<=0)&&(h <= 0.9) then ' three quarters of an hour'
                  elsif (h_f==1)&&(h <= 0.2) then ' hour'
                  elsif (h_f>=2)&&(h <= 0.2) then ' hours'
                  elsif (h_f>=1)&&(h <= 0.4) then ' and a quarter hours'   
                  elsif (h_f>=1)&&(h <= 0.6) then ' and a half hours'
                  elsif (h_f>=1)&&(h <= 1.0) then ' and three quarters hours'
                  else ' some time'
                  end

        msg_end = ' ago.'

        return msg = msg_start + msg_mid + msg_end
      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # SECTION: Twilio Helpers
    ###########################################################################

    ###########################################################################
    # Twilio-Specific 'Macro'-style Helper: Send SMS to a number
    ###########################################################################
    def send_SMS_to( number, msg )
      where = 'HELPER: ' + (__method__).to_s 
      begin
        puts "ATTEMPT TO SMS TO BAD NUMBER" if number.match(/\+1\d{10}\z/)==nil

        @message = $twilio_account.sms.messages.create({
              :from => ENV['TWILIO_CALLER_ID'],
              :to => number,
              :body => msg
        })
        puts "SENDING OUTGOING SMS: "+msg+" TO: "+number

      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # Twilio-Specific 'Macro'-style Helper: Send SMS back to caller
    ###########################################################################
    def reply_via_SMS( msg )
      where = 'HELPER: ' + (__method__).to_s
      begin
        @message = $twilio_account.sms.messages.create({
              :from => ENV['TWILIO_CALLER_ID'],
              :to => params['From'],
              :body => msg
        })
      puts "REPLYING WITH AN OUTGOING SMS: "+msg+" TO: "+params['From']

      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # Twilio-Specific 'Macro'-style Helper: Dial out to a number
    ###########################################################################
    def dial_out_to( number_to_call, route_to_execute )
      where = 'HELPER: ' + (__method__).to_s 
      begin
        @call = $twilio_account.calls.create({
              :from => ENV['TWILIO_CALLER_ID'],
              :to => number_to_call,
              :url => "#{SITE}" + route_to_execute
       })
       puts "DIALING OUT TO: "+number_to_call

      rescue Exception => e;  log_exception( e, where );  end
    end #def


    ###########################################################################
    # App-Specific 'Macro'-style Helper: Schedule a text-back to a num
    ###########################################################################
    def schedule_textback_to( number_to_call )
      where = 'HELPER: ' + (__method__).to_s 
    begin
      doc = {
       'ID' => params['From'],
       'msg' => 'Hey there! Have you rechecked your blood sugar yet? Just wanted to make sure that you addressed your low. Let us know with a normal checkin!', 
       'utc' => Time.now.to_f
      }
      DB['textbacks'].insert(doc)

      puts "Scheduling textback TO: "+number_to_call

      rescue Exception => e;  log_exception( e, where );  end
    end #def



    ###########################################################################
    # App-Specific Helper: Reset Alarm Timer for a ph_num (NOT NOW USED)
    ###########################################################################
    def reset_alarm_timer_for( ph_num )
    where = 'alarm reset helper'
    begin
      doc = DB['people'].find_one({'_id' => ph_num })
      doc['strikes'] = 0
      doc['timer'] = doc['alarm']
      DB['people'].save(doc)

      rescue Exception => e;  log_exception( e, where );  end
    end #def reset alarm timer


    ###########################################################################
    ###########  Application-specific Mongo DB Access Helpers  ################
    ###########################################################################


    ###########################################################################
    # Helper: Map an incoming parent's ph_num to their child's number.
    # If no mapping exists, assume caller IS (or is-to-be) a patient...
    ###########################################################################
    def patient_ph_num_assoc_wi_caller
      map_to = DB['groups'].find_one('CaregiverID' => params['From']) 

      patient_ph_num = params['From'] if (map_to==nil)
      patient_ph_num = map_to['PatientID'] if (map_to!=nil)      

      return patient_ph_num
    end #def

    ###########################################################################
    # Helper: Message entire care team
    ###########################################################################
    def msg_all_caregivers (msg)
      mapped_to = DB['groups'].find({ 'PatientID' => params['From'], 
                                      'CaregiverID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['CaregiverID'], msg)
        puts "Texting" + r['CaregiverID']
        puts "With msg: " + msg
      end 
    end #def

    ###########################################################################
    # Helper: Globally message ALL caregivers in the study
    ###########################################################################
    def global_caregiver_broadcast (msg)
      mapped_to = DB['groups'].find({ 'CaregiverID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['CaregiverID'], msg)
        puts "Texting" + r['CaregiverID']
        puts "With msg: " + msg
      end
    end #def

    ###########################################################################
    # Helper: Message all patients in the study who are in at least one group
    ###########################################################################
    def global_patients_with_caregivers_broadcast (msg)
      mapped_to = DB['groups'].find({ 'PatientID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['PatientID'], msg)
        puts "Texting" + r['PatientID']
        puts "With msg: " + msg
      end
    end #def

    ###########################################################################
    # Helper: Message everyone in the study, period 
    ###########################################################################
    def global_broadcast (msg)
      mapped_to = DB['people'].find({ 'ID' => {'$exists' => true} })
      mapped_to.each do |r|
        send_SMS_to(r['ID'], msg)
        puts "Texting" + r['ID']
        puts "With msg: " + msg
      end
    end #def

    ###########################################################################
    # Helper: Message any one member from the care team
    ###########################################################################
    def msg_caregiver_of ( ph_num, msg )
      map = DB['groups'].find_one('PatientID' => ph_num, 
                                  'CaregiverID' => {'$exists' => true} )

      send_SMS_to( map['CaregiverID'], msg ) if map != nil
    end #def

    ###########################################################################
    #
    # One key with Mongo is to minimize the size of stored keys and val's
    # because Mongo's performance suffers unless you have enough main 
    # system memory to hold about 30 - 40% of the total size of the 
    # collections you will want to access.  
    #
    # A straightforward way to help with this is to store an "abbreviation
    # dictionary" . . .  which we can also put in Mongo!
    #
    ###########################################################################

    ###########################################################################
    # Helper: Map abbreviations to full text strings.  .  .
    ###########################################################################
    def full_string_from_abbrev( tag_abbrev_s )
      where = "HELPER: " + (__method__).to_s
 
      record = DB['abbrev'].find_one('abbreviation' => tag_abbrev_s)
      when_s = record['full'] if record != nil
      when_s = tag_abbrev_s if record == nil

      return when_s
    end #def


    ###########################################################################
    # Helper: Arbitrary-checkin database interactions
    ###########################################################################
    def handle_checkin(value_f, flavor_text_s)
    puts where = 'handle_checkin'
    begin
      pts = DEFAULT_POINTS
      value_s = value_f.to_s

      doc = { 'ID' => params['From'],
              flavor_text_s => value_f,
              'flavor' => flavor_text_s, 
              'value_s' => value_s, 
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = "Got your checkin! Logging %.1f %s" % [value_f, flavor_text_s]

    rescue Exception => e
      msg = 'Unable to log checkin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Handle arbitrary tagged-checkin database interactions
    ###########################################################################
    def handle_tagged_checkin(value_f, flavor_text_s, tag_s)
    puts where = 'handle_tagged_checkin'
    begin
      pts = DEFAULT_POINTS
      value_s = value_f.to_s

      doc = { 'ID' => params['From'],
              flavor_text_s => value_f,
              'flavor' => flavor_text_s,
              'value_s' => value_s,
              'tag_s' => tag_s, 
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = "Got your checkin!"
      msg += " Logging %.1f %s, %s" % [value_f, flavor_text_s, tag_s]

    rescue Exception => e
      msg = 'Unable to log checkin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def




    ###########################################################################
    # Helper: Glucose-checkin database interactions
    # Give bonus points for a bg check 2-3 hours after the last meal
    # Give bonus points for a bg check 0-20 mins after a prior low bg check
    ###########################################################################
    def handle_glucose_checkin(mgdl, tag_abbrev_s)
    puts where = 'handle_glucose_checkin  helper'
    begin
      pts = tag_abbrev_s == '' ? 10.0 : 15.0
      msg = ''

      hi = @this_user['hi']
      lo = @this_user['lo']

      when_s = full_string_from_abbrev( tag_abbrev_s )

      last_c = last_carb_lvl_for( params['From'] )
      interval_in_hours = last_c==nil ? 0 : (@now_f - last_c['utc']) / ONE_HOUR
      pts +=10.0 if ((interval_in_hours > 1.9)&&(interval_in_hours < 3.6))
      
      DB['textbacks'].remove({'ID'=>params['From']}) if (interval_in_hours<0.2)

      last_g = last_glucose_lvl_for( params['From'] )
      g_interval_in_hours = last_g==nil ? 0 : (@now_f - last_g['utc'])/ONE_HOUR

      if (last_g == nil)
        time_of_last_checkin = 'not found'
      else
        if (last_g['mg'] < @this_user['lo'])
          msg_all_caregivers('Your child just rechecked, latest BG: '+mgdl.to_s)
          if ((interval_in_hours > 0.00)&&(interval_in_hours < 0.6))
            pts +=10.0
          end
        end #if
      end #if
      
      doc = { 'ID' => params['From'], 
              'mg' => mgdl, 
              'tag' => tag_abbrev_s, 
              'pts' => pts, 
              'utc' => @now_f 
            }
      DB['checkins'].insert(doc)

      msg = 'Thanks! Got:' +mgdl.floor.to_s+' mg/dL'
      msg += ' for your '+when_s+' checkin' 
      msg += ' (+' + pts.to_s + ' pts!)'

      if ((mgdl > hi)&&(last_g!=nil))
       if ((last_g['mg'] > hi) && (last_g['utc'] > @now_f-5*ONE_HOUR)) 
        msg += ' Hm, >'+hi.to_s+' 2X in a row, maybe check ketones?' 
        msg_all_caregivers( 'Last 2 checkins high, latest = ' + mgdl.to_s )
       end
      elsif (mgdl < lo)
        msg += ' Hm, <'+lo.to_s+' Take tabs or juice & recheck?'
        msg_all_caregivers( 'Latest checkin was low:' + mgdl.to_s + ' but child advised to take carbs and recheck' )
        schedule_textback_to( params['From'] )
      end

    # check_for_victory( params['From'] )
    rescue Exception => e
      puts msg = 'Unable to log glucose!!!'
      log_exception( e, where )
    end
      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Lantus-checkin database interactions
    ###########################################################################
    def handle_lantus_checkin(units_f, tag_abbrev_s)
    puts where = 'handle_lantus_checkin'
    begin
      pts = tag_abbrev_s == '' ? 20.0 : 20.0

      doc = { 'ID' => params['From'],
              'Lantus' => units_f,
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = "Great! Logging %.1f Lantus units. +%.0f pts " % [units_f, pts]

    rescue Exception => e
      msg = 'Unable to log Lantus'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Insulin-checkin database interactions
    #
    # If there has been an insulin checkin less than 2 hours ago, 
    # then issue a cautionary note...
    # 
    ###########################################################################
    def handle_insulin_checkin(units_f, tag_abbrev_s, ins_type='ins')
    puts where = 'handle_insulin_checkin'
    begin
      pts = tag_abbrev_s == '' ? 5.0 : 10.0
      msg = ''

      ph_num = params['From']

      ins_type_s = full_string_from_abbrev( ins_type )
      when_s = full_string_from_abbrev( tag_abbrev_s )

      prev_i = last_insulin_lvl_for(ph_num)
      if (prev_i != nil)
        if ( (prev_i['utc'] + 2*ONE_HOUR) > @now_f ) 
          msg += 'Careful! Insulin is within 2 hours of prior dose... '
        end
      end
 
      doc = { 'ID' => params['From'],
              'units' => units_f,
              'What' => ins_type_s,
              'tag' => tag_abbrev_s, 
              'pts' => pts, 
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg += 'Logging '+units_f.to_s+' units of '+ins_type_s+', '+when_s
      msg += ' +' + pts.to_s + ' pts'

    rescue Exception => e
      msg = 'Unable to log insulin'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def


    ###########################################################################
    # Helper: Carb checkin database interactions
    #
    # If the last glucose report was LO and < 20 mins ago, give bonus pts.
    #
    ###########################################################################
    def handle_carb_checkin(g_f, tag_abbrev_s)
    puts where = 'handle_carb_checkin'
    begin
      pts = tag_abbrev_s == '' ? 5.0 : 10.0

      last_c = last_carb_lvl_for( params['From'] )
      interval_in_hours = last_c==nil ? 99 : (@now_f - last_c['utc']) / ONE_HOUR
# Disable cheat-proofing-by-carb-splitting for now
#      pts = 0.0 if (interval_in_hours < 1.0)
   
      lo = @this_user['lo']
      msg = ''

      when_s = full_string_from_abbrev( tag_abbrev_s )

      last_level = last_glucose_lvl_for( params['From'] )
      if (last_level == nil)
        time_of_last_checkin = 'never'
      else
        interval_in_mins = (Time.now.to_f - last_level['utc']) / 60.00
        pts +=10.0 if ((interval_in_mins < 20.0)&&(last_level['mg'] < lo))
        msg += ' [*Bonus Points* for counteracting a low bg] '
      end #if

      doc = {
              'ID' => params['From'],
              'g' => g_f,
              'tag' => tag_abbrev_s,
              'pts' => pts,
              'utc' => @now_f
            }
      DB['checkins'].insert(doc)

      msg = 'Logged '+g_f.floor.to_s+'g carbs, '+when_s+', +'+pts.to_s+'pts'

    rescue Exception => e
      msg = 'Unable to log carbs'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def

    ###########################################################################
    # Helper: Typo Correction
    # If the user notices a typo immediately, we can correct the prior number
    ###########################################################################
    def revise_last_checkin_to( new_value_s )
    puts where = 'revise_last_checkin_to'
    begin
      new_f = Float(new_value_s)

      db_cursor = DB['checkins'].find({'ID' => params['From']})
      db_record = db_cursor.sort('utc' => -1).limit(1).first
      
      if (db_record==nil)

        msg = 'We do not have any checkins from you yet!'

      else

        id = db_record['_id']

        if (db_record['mg']!=nil)
          msg = 'Updating last sugar checkin to:'+new_f.to_s
          DB['checkins'].update({'_id' => id},
                            {"$set" => {'mg' => new_f}})
        elsif (db_record['units']!=nil)
          msg = 'Updating last insulin checkin to:'+new_f.to_s
          DB['checkins'].update({'_id' => id},
                            {"$set" => {'units' => new_f}})
        elsif (db_record['g']!=nil)
          msg = 'Updating last carb checkin to:'+new_f.to_s
          DB['checkins'].update({'_id' => id},
                            {"$set" => {'g' => new_f}})
        else
          msg = 'Sorry, cannot tell exactly what you want to update.'
        end

      end #if

    rescue Exception => e
      msg = 'Unable to log correction'
      log_exception( e, where )
    end

      reply_via_SMS(msg)
    end #def



    ###########################################################################
    # "DB Fetch" accessor-type Methods for the various tracked quantities
    ###########################################################################
    # Please Note: These may return 'nil' so check value on the other side...
    # Also Note: These return the entire record found, in a hash, not just
    #            one number or one string with the value in it
    ###########################################################################
    def last_checkin()
      db_cursor = DB['checkins'].find()
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_checkin_for(ph_num)
      db_cursor = DB['checkins'].find({ 'ID' => ph_num })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_glucose_lvl_for(ph_num)
      db_cursor = DB['checkins'].find({ 'ID' => ph_num,
                                        'mg' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_insulin_lvl_for(ph_num)
      db_cursor = DB['checkins'].find({ 'ID' => ph_num, 
                                        'units' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level        
    end #def

    def last_carb_lvl_for(ph_num)
      db_cursor = DB['checkins'].find({ 'ID' => ph_num,
                                        'g' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level
    end #def

    def last_goal_for(ph_num)
      db_cursor = DB['checkins'].find({ 'ID' => ph_num,
                                        'goal' => {'$exists' => true} })
      enum = db_cursor.sort(:utc => :desc)
      last_level = enum.first

      return last_level
    end #def


    ###########################################################################
    ###########################################################################
    # Accessor-type Helpers returning string (msg) values
    ###########################################################################
    ###########################################################################

    ###########################################################################
    # Score Helper
    ###########################################################################
    def score_for( ph_num )
    puts where = 'score_for  helper'
    begin
      msg = ''
      cmd = {
        aggregate: 'checkins',  pipeline: [
          {'$match' => {:ID => ph_num}},
          {'$group' => {:_id => '$ID', :pts_tot => {'$sum'=>'$pts'}}} ]
      }
      result = DB.command(cmd)['result'][0]
      score = result==nil ? DEFAULT_SCORE : result['pts_tot']
      msg = " Score: %.0f " % score
      
      last = last_goal_for( ph_num )

      goal = last==nil ? 'None.' : (last['goal']).floor
      msg += ' Goal: ' + goal.to_s

      if last != nil
        days_f = (Time.now.to_f - last['utc']) / ONE_DAY
        daystogo = 7.0 - days_f
        ptstogo = goal - score
        msg += " Only %.1f days and %d points to go!" % [daystogo, ptstogo]
      end #if last

    rescue Exception => e  
      msg += "  Goal info not available"
      log_exception( e, where )
    end

      return msg
    end #def


    ###########################################################################
    # Check-For-Victory  Helper
    ###########################################################################
    def check_for_victory( ph_num )
    puts where = 'check_for_victory  helper'
    begin
      msg=''
      cmd = {
        aggregate: 'checkins',  pipeline: [
          {'$match' => {:ID => ph_num}},
          {'$group' => {:_id => '$ID',:pts_tot => {'$sum'=>'$pts'}}} ]
      }
      result = DB.command(cmd)['result'][0]
      score = result==nil ? DEFAULT_SCORE : result['pts_tot']

      last = last_goal_for( ph_num )

      if last != nil
        goal = last['goal'] ==nil ? DEFAULT_GOAL : last['goal']

        days_f = (Time.now.to_f - last['utc']) / ONE_DAY

        if (score+0.001 > goal)
          msg += "GOAL ACHIEVED! %.0f points earned" % score
          msg += " in %.2f days." % days_f
          msg += '  Text, for example, goal123 to set a new goal of 123 points'

          send_SMS_to( ph_num, msg )
          msg_caregiver_of( ph_num, msg )

#         normalize_score_to_zero_for( ph_num )
          doc = {
              'ID' => ph_num,
              'victory' => score,
              'pts' => -1 * score, 
              'utc' => Time.now.to_f
          }
          DB['checkins'].insert(doc)

        end
      end #if last

      if last == nil
        send_SMS_to( ph_num, 'Congrats on getting points! Set up a goal so you can get a reward :) For example, text Goal123 to set a goal of 123 points' )
      end

    rescue Exception => e
      log_exception( e, where )
    end

    end #def


    ###########################################################################
    # Check-Progress-at-Midweek  Helper
    ###########################################################################
    def check_progress_midweek( ph_num )
    puts where = 'check_progress_midweek'
    begin
      msg=''
      cmd = {
        aggregate: 'checkins',  pipeline: [
          {'$match' => {:ID => ph_num}},
          {'$group' => {:_id => '$ID',:pts_tot => {'$sum'=>'$pts'}}} ]
      }
      result = DB.command(cmd)['result'][0]
      puts score = result==nil ? DEFAULT_SCORE : result['pts_tot']

      last = last_goal_for( ph_num )

      if last == nil
        send_SMS_to( ph_num, "Morning! :)  Text Goal123 to set a goal of 123?" )
      end #if

      if last != nil
        puts goal = last['goal'] ==nil ? DEFAULT_GOAL : last['goal']

        days_f = (Time.now.to_f - last['utc']) / ONE_DAY

        if ((score+0.001 < goal)&&(days_f > 3.0))
          msg += " Good Morning!  You have earned %0.f pts..." % (score)
          msg += " Only %0.f pts more to go!" % (goal - score)
          send_SMS_to( ph_num, msg )
        end #if send report sms

      end #if last


    rescue Exception => e
      log_exception( e, where )
    end

    end #def


    ###########################################################################
    # Settings Info Helper
    ###########################################################################
    def info_for( ph_num )
    puts where = 'info_for  helper'
    begin
      record = DB['people'].find_one({ '_id' => ph_num })
      lo_s = record['lo'] != nil ? (record['lo']).to_s  : DEFAULT_LO.to_s
      hi_s = record['hi'] != nil ? (record['hi']).to_s  : DEFAULT_HI.to_s
      alarm_s = record['alarm'] != nil ? (record['alarm']).to_s  : 'None'
      
      msg = 'Info for: ' + ph_num + '...  '
      msg += '  Lo = ' + lo_s
      msg += '  Hi =' + hi_s
      msg += '  Alarm = ' + alarm_s

    rescue Exception => e
      msg = 'Status Unavailable.'
      log_exception( e, where )
    end

      return msg
    end #def


    ###########################################################################
    # Weekly Summary Helper
    #
    # Fetch any low bg checkins and also all other checkins for the past week
    # 
    # Aggregate checkins to get totals and averages
    # 
    ###########################################################################
    def weekly_summary_for( ph_num )
    puts where = 'weekly_summary_for  helper'
    begin
      msg = ''
      lc = DB['checkins'].find({'ID' => ph_num,
                                'mg' => {'$lt' => @this_user['lo']},
                                'utc' => {'$gte' => (@now_f-ONE_WEEK)} })
      tc = DB['checkins'].find({'ID' => ph_num,
                                'utc' => {'$gte' => (@now_f-ONE_WEEK)}})
      gc = DB['checkins'].find({'ID' => ph_num,
                                'mg' => {'$lt' => 99999},
                                'utc' => {'$gte' => (@now_f-ONE_WEEK)} })
      lows = lc.count
      tot_checkins = tc.count
      glucose_checkins = gc.count

      msg = "WEEKLY STATS: "
      msg +="%d total checkins this week; " % tot_checkins
      msg +="%d total BG checks; " % glucose_checkins 
      msg +="%d low-BG events; " % lows

      cmd = {
       aggregate: 'checkins',  pipeline: [
        {'$match' => {'ID' => ph_num, 
                      'utc' => {'$gte' => (@now_f-ONE_WEEK)}}   },
        {'$group' => {:_id =>'$ID',
                      :tot_bg => {'$sum'=>'$mg'},
                      :tot_ins => {'$sum'=>'$units'},
                      :tot_carb => {'$sum'=>'$g'},
                      :earliest => {'$min'=>'$utc'}       }}       ]
      }
      tot_h = (DB.command(cmd)['result'])[0]
      tot_bg = tot_h['tot_bg']
      tot_carbs = tot_h['tot_carb']
      tot_insulin = tot_h['tot_ins']

      days_elapsed_actual = (@now_f - tot_h['earliest']) / ONE_DAY
      days_elapsed = days_elapsed_actual<1.0? 1.0 : days_elapsed_actual

      num_glucose_checkins = glucose_checkins<0.001? 1:glucose_checkins
      typ_bg = tot_bg / num_glucose_checkins

      ave_checkins = num_glucose_checkins / days_elapsed 
      ave_carbs = tot_carbs / days_elapsed 
      ave_insulin = tot_insulin / days_elapsed 
    
      msg +="%.0f ave BG; " % typ_bg
      msg += "%.1f BG checks/day, " % ave_checkins
      msg += "%.1fg carbs/day, " % ave_carbs
      msg += "%.1f units insulin/day" % ave_insulin

    rescue Exception => e
      msg += ' Cannot complete week-summary yet'
      log_exception( e, where )
    end

      return msg
    end #def



    ###########################################################################
    # Suppose you want to introduce folks to the app by sending them 
    # an SMS . . .  can do!  We might then like to 'recognize' them as they
    # show up / call in . . .   
    ###########################################################################
    def onboard_a_brand_new_user
      where = "HELPER: " + (__method__).to_s 

      begin

      doc = {
         '_id' => params['From'],
          'alarm' => DEFAULT_PANIC,
          'timer' => DEFAULT_PANIC,
          'goal' => DEFAULT_GOAL, 
          'strikes' => 0,
          'hi' => DEFAULT_HI,
          'lo' => DEFAULT_LO
        }
        DB['people'].insert(doc)

        msg = 'Welcome to the experimental tracking app!'
        msg += ' (All data sent or received is public domain.)'
        reply_via_SMS( msg )

      rescue Exception => e;  log_exception( e, where );  end
    end



    ###########################################################################
    # Cross-Application Mongo DB Access Helpers (Twilio Case)  
    ###########################################################################
    # register_email_in_db finds the 'people' entry corresponding to the
    # phone number that is calling / texting us, and adds and/or updates
    # the email on file for that person.
    ###########################################################################
    def register_email_in_db(em)
      DB['people'].update({'_id' => params['From']},
                          {"$addToSet" => {'email' => em}}, :upsert => true)
    end #def

  end #module

TheApp.helpers HelpersForTheApp


