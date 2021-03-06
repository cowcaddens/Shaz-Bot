#!/bin/ruby

require 'mumble-ruby'
require 'yaml'
require 'pp'

begin
	CONFIG = YAML.load_file('config.yml') unless defined? CONFIG
rescue Errno::ENOENT
	abort 'Config.yml not found. You can copy, rename and edit config-sample.yml to fix this problem.'
end
STDOUT.sync = true


class Shaz_Bot
	attr_accessor :cli

	def initialize
		@cli = Mumble::Client.new(CONFIG['address'], CONFIG['port']) do |conf| # This segment inherits the bots basic data from the config.yml file
			conf.username = CONFIG['username']
			conf.password = CONFIG['password'] if CONFIG['password']
		end
		@roleList = CONFIG['role_List']
		userInput
	end

	def hashYmlUpdate
		players = YAML.load_file('HashStore.yml')
		for i in 0..@cli.users.count-1 do
			usrkey = @cli.users.keys[i]
			hshNm = @cli.users[usrkey].hash
			if players.include?(:"#{hshNm}") == true then
				puts "the players current name is #{@cli.users[usrkey].name} and the channel id is #{@cli.users[usrkey].channel_id}"
				players[:"#{hshNm}"][:name] = @cli.users[usrkey].name
				total = 0
				for i in 0..6 do
					roleName = players[:"#{hshNm}"][:playerSkills].keys[i]
					total = total + players[:"#{hshNm}"][:playerSkills][:"#{roleName}"]
				end
				players[:"#{hshNm}"].merge!(:skillTotal => total)
			else
				defautPlayerSkills = {:hof => 2.0,:ld => 2.0,:cap => 2.0,:offence => 4.0,:snipe => 1.0,:gamesense => 3.0,:fragging => 3.0}
				tmpH = {:name => @cli.users[usrkey].name,:hash => @cli.users[usrkey].hash}
				tmpH.merge!(:playerSkills => defautPlayerSkills)
				pp (tmpH)
				players.merge!(:"#{hshNm}" => tmpH)
			end #make the feature that puts the usr into a hash
		end
		File.open('HashStore.yml','w') {|f1| f1.write(players.to_yaml)} #here commit all those hashes to the players{} hash and save that to the hash file.
	end

	def onlinePlayers # Gets a hash list of all online players and their position.
		onPlayers = {}
		for i in 0..@cli.users.count-1 do
			usrkey = @cli.users.keys[i]
			hshNm = @cli.users[usrkey].hash
			if @cli.users[usrkey].channel_id == CONFIG['priority_players']['normal'] or @cli.users[usrkey].channel_id == CONFIG['priority_players']['quiet'] then
				onPlayers.merge!(:"#{hshNm}" => true) # The key is used to store player hash data and the true/false stores fat data for said player
			elsif @cli.users[usrkey].channel_id == CONFIG['waiting_players']['normal'] or @cli.users[usrkey].channel_id == CONFIG['waiting_players']['quiet'] then
				onPlayers.merge!(:"#{hshNm}" => false) # As above except false for not fat
			end
		end
		return onPlayers
	end

	def teamMove(teamHash, room)
		for i in 0..teamHash.length-1 do
			@cli.move_user_hash(teamHash[:"#{teamHash.keys[i]}"],room) # this calls a function in the mumble-ruby library which moves users via their hash
			sleep(1) # sleep just because it makes the movement of players look nicer :D
		end
	end

	def teamCompositionGet
		teamBE = {}
		teamDS = {}
		playeryml = YAML.load_file('HashStore.yml')
		onlinePlayerList = onlinePlayers()
		if onlinePlayerList.length < 14 then
			puts "not enough players to move"
			return
		end
		for i in 0..@roleList.length-1 do
			playerSelected = simpleSelect(CONFIG['team1']['name'], @roleList[:"role#{i+1}"], 3, onlinePlayerList)
			pp playerSelected
			teamBE[:"#{@roleList.keys[i]}"] = playerSelected
			playerSelected = simpleSelect(CONFIG['team2']['name'], @roleList[:"role#{i+1}"], 3, onlinePlayerList)
			pp playerSelected
			teamDS[:"#{@roleList.keys[i]}"] = playerSelected
		end
		while onlinePlayerList.has_value?(true) do # this loop is used to first check for any fat people not picked
			puts onlinePlayerList.key(true) # This will select an unselected fatman, and when I have time, the sort in function will come after
			break
		end
		pp teamBE
		teamMove(teamBE, CONFIG['team1']['room']) # The room here is the Blood Eagle mumble room
		teamMove(teamDS, CONFIG['team2']['room']) # The number here is the Diamond Sword room
	end

	def simpleSelect(team, role, severity, playerlist) # Ask Mcoot about this
		skillyml = {}
		playerDataList = YAML.load_file('HashStore.yml')
		for i in 0..playerlist.length-1 do
			skillyml[:"#{playerlist.keys[i]}"] = (playerDataList[:"#{playerlist.keys[i]}"][:playerSkills][:"#{role}"]*(playerDataList[:"#{playerlist.keys[i]}"][:playerSkills][:"#{role}"]/playerDataList[:"#{playerlist.keys[i]}"][:skillTotal])*10).round
		end
		skillyml = skillyml.sort_by {|k, v| -v}[0..severity].to_h
		for i in 0..skillyml.length-1 do
			if i == 0 then
				skillyml[skillyml.keys[i]] = (0..skillyml[:"#{skillyml.keys[i]}"]-1).to_a
			else
				skillyml[skillyml.keys[i]] = (skillyml[:"#{skillyml.keys[i-1]}"].max+1..skillyml[:"#{skillyml.keys[i]}"]+skillyml[:"#{skillyml.keys[i-1]}"].max).to_a
			end
		end
		randomNumber = rand(skillyml.values.flatten.max)
		for i in 0..skillyml.length-1 do
			if skillyml[:"#{skillyml.keys[i]}"].include?(randomNumber) then
				puts "#{skillyml.keys[i]} picked for #{team}'s #{role} and their score is #{skillyml[skillyml.keys[i]]}"
				playerlist.delete(skillyml.keys[i])
				return "#{skillyml.keys[i]}"
			end
		end
	end

	def relativeSkillSelect(team, severity, playerlist) # A sort to select players only by skill, not role, just an idea atm.
		skillyml = {}
		playerDataList = YAML.load_file('HashStore.yml')
		for i in 0..playerlist.length-1 do
			skillyml[:"#{playerlist.keys[i]}"] = (playerDataList[:"#{playerlist.keys[i]}"][:playerSkills][:gamesense]*1.3+playerDataList[:"#{playerlist.keys[i]}"][:playerSkills][:fragging]*10).round
		end
	end

	def userInput
		@cli.on_text_message do |msg|
			puts msg.message
			hashYmlUpdate
			teamCompositionGet
		end
	end
end

shazbot = Shaz_Bot.new
shazbot.cli.connect
loop do
	sleep(1)
end
