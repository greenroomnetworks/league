# { name: "Tom's Fault", players_required: 5, player_ids: [...], 
#    logo: {lines: ["Tom's Fault"], shape: 'diamond', colors: ["#xxx", "#yyy"], font: 'Foogle'} }

class Team extends Model
  @_collection: Teams
  constructor: (attrs) ->
    super(attrs)
    @attributes.player_ids ||= []
    
    # is this a hack?
    @prepare_logo() if Meteor.is_client
  
  valid: ->
    @errors = {}
    
    # Obviously we'd prefer rails style class-level validators
    unless @attributes.name? and @attributes.name != ''
      @errors.name = 'must not be empty'
    
    # this is a bit of a hack. Players will be totally empty (and not include current_user) 
    # if it hasn't loaded yet. This is a work around for now..
    unless @players().count() > 0 or (@attributes.player_ids.length > 0 and not Players.findOne())
      @errors.players  = 'must not be empty'
    
    _.isEmpty(@errors)
  
  # many-many association. TODO: generalize this I guess
  players: (conditions = {}, options = {}) ->
    conditions._id = {$in: @attributes.player_ids}
    Players.find(conditions, options)
  
  games: (conditions = {}, options = {}) -> 
    conditions.team_id = @id
    options.sort ||= {date: 1}
    Games.find(conditions, options)
  
  future_games: -> @games({date: {$gt: moment().valueOf()}})
  
  next_game: -> @future_games()[0] || null
  
  player_deficit: -> if @next_game() then @next_game().player_deficit() else 0
  
  unauthorized_count: -> this.players({authorized: undefined}).count()
  authorized: ->  @unauthorized_count() == 0
  
  team_done: ->
    !! @attributes.players_required
  
  # TODO -- should this be more than players_required?
  roster_done: ->
    @players().count() > 1
  
  done: ->
    @team_done() and @roster_done()
  
  add_player: (player) ->
    # add player to this
    player.save() unless player.persisted()
    @update_attribute('player_ids', _.union(@attributes.player_ids, [player.id]))
    
    # add this to player
    player.update_attribute('team_ids', _.union(player.attributes.team_ids, [@id]))
    
    this
  
  # go to the server and try and find a player, then call the above
  # TODO is there some way to automatically create a method here?
  add_player_from_email: (email) ->
    Meteor.call 'add_player_to_team_from_email', @id, email
  
  remove_player: (player) ->
    # remove player from this
    @update_attribute('player_ids', _.without(@attributes.player_ids, player.id))
    
    # remote this from player
    player.update_attribute('team_ids', _.without(player.attributes.team_ids, @id))
    
    this
  
  create_game: (attributes) ->
    @save() unless @persisted()
    
    attributes.team_id = this.id
    Game.create(attributes)
  
  create_next_game: ->
    now = moment()
    last_game = @games({}, {sort: {date: -1}, limit: 1})[0]
    
    # last game is in the future
    if last_game
      new_game = last_game.clone_one_week_later()
      
      # new game could be in the past, need to ensure it's in the future
      new_game.add('weeks', 1) while now.diff(new_game) < 0
    
    else
      # there is no last game, we need to create the very first game for this team.
      date = moment().add('days', 1).hours(20).minutes(0)
      new_game = new Game({team_id: current_team().id, date: date.valueOf()})
    
    new_game.save();
  
  prepare_logo: (regenerate = false) ->
    if @attributes.logo? and not regenerate
      @logo = new Logo(this, @attributes.logo)
    else
      @logo = new Logo(this)
      @attributes.logo = @logo.to_object()

Team.has_access = (userId, teams) ->
  # just check that the player is in the team
  _.include(teams[0].attributes.player_ids, Player.find_by_userId(userId).id)
  
Teams = Team._collection = new Meteor.Collection 'teams', {ctor: Team}

## add security
Teams.allow
  insert: (userId) -> !! userId
  update: Team.has_access
  remove: Team.has_access
  