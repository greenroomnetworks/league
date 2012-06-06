# generic events used by both the next_game and the upcoming games
Template.games.editable_game_events = 
  'click .editable': (event) ->
    $form = $(event.currentTarget).closest('form')
    field = $(event.currentTarget).attr('data-field')
    open_edit_field field, this, ->
      console.log 'edit field done'
        # this.save_moment()
        # Meteor.flush()

  'submit form': (e) ->
    e.preventDefault()
    $(e.target).find('[name]').trigger('blur') # to trigger the changed event
    
  'change [name=location]': (e) -> this.attributes.location = $(e.target).val()
  'change [name=hours]': (e) -> 
    this.game.set_hours($(e.target).val())
    console.log this.game.moment.hours()
  'change [name=minutes]': (e) -> this.game.set_minutes($(e.target).val())
  'click .close': (e) -> Meteor.defer -> close_current_edit_field()

# any click anywhere will close the currently editing field
Template.games.events = 
  'click': ->
    # unless the click is inside an editable
    unless $(event.target).is('.editable') or $(event.target).closest('.editable').length
      close_current_edit_field()
    

Template.games.team = -> current_team()
Template.games.next_game = Template.next_game.next_game = -> future_games()[0]
Template.upcoming_games.upcoming_games = -> 
  future_games()[1..]

Template.upcoming_games.events =
  'click .create_game': (event) -> 
    event.preventDefault();
    new_game = current_team().create_next_game()
    console.log "Game invalid: #{new_game.full_errors()}" unless new_game.valid()
    
Template.next_game.location_or_game_number = ->
  this.attributes.location || "Game #{this.game_number()}"

Template.next_game.player_availabilities = Template.game.player_availabilities = -> 
  for p in this.players()
    availability = {game: this, player: p}
    # need to circularly link so we can get access to info when events happen FIXME
    availability.player.availability = availability
    availability

Template.next_game.events = _.extend Template.games.editable_game_events, {}

Template.game.month = -> this.moment.format('MMM')
Template.game.expanded = -> Session.equals("game.#{this.id}.expanded", true)
Template.game.current_user_availability = -> this.availability(current_user())

Template.game.events = _.extend Template.games.editable_game_events,
  'change [name=state]': (e) ->
    playing = $(e.target).val() == 'play'
    if playing
      this.playing(current_user())
    else
      this.not_playing(current_user())
  'click .go_unconfirmed': ->
    this.unconfirmed(current_user())
  'click .show_roster': -> 
    Session.set("game.#{this.id}.expanded", true)
  'click .hide_roster': -> 
    Session.set("game.#{this.id}.expanded", false)

Template.date_chooser.date_format = 'MM d, yy'
Template.date_chooser.date_for_input = -> this.formatted_date()
Template.date_chooser.date_field_id = -> "game-#{this.id}-datepicker"
Template.date_chooser.attach_date_picker = ->
  Meteor.defer =>
    game = this
    $("\#game-#{this.id}-datepicker")
      .datepicker
        dateFormat: Template.date_chooser.date_format
        minDate: new Date()
        onSelect: (dateText) -> 
          game.set_date($.datepicker.parseDate(Template.date_chooser.date_format, dateText))

Template.date_chooser.possible_hours = ->
  game: this
  name: 'hours'
  options: ({text: "#{h}h", value: h, selected: h == this.hours()} for h in [1..24])
  
Template.date_chooser.possible_minutes = ->
  game: this
  name: 'minutes'
  options: ({text: "#{min}m", value: min, selected: min == this.minutes()} for min in [0...60] when min % 5 == 0)


Template.player_availability.facebook_profile_url = -> 
  this.facebook_profile_url()

Template.player_availability.availability = -> 
  this.game.availability(this.player)
Template.player_availability.unconfirmed = ->
  this.game.availability(this.player) == 0


Template.player_availability.events =
  'click li.player': ->
    console.log this
    console.log this.availability
    this.availability.game.toggle_availability(this)
