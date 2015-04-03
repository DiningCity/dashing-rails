Batman.config.pathPrefix = "/"
Batman.config.pathToHTML = "/dashing/widgets/"

Batman.Filters.prettyNumber = (num) ->
	num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") unless isNaN(num)

Batman.Filters.dashize = (str) ->
	dashes_rx1 = /([A-Z]+)([A-Z][a-z])/g;
	dashes_rx2 = /([a-z\d])([A-Z])/g;

	return str.replace(dashes_rx1, '$1_$2').replace(dashes_rx2, '$1_$2').replace(/_/g, '-').toLowerCase()

Batman.Filters.shortenedNumber = (num) ->
	return num if isNaN(num)
	if num >= 1000000000
		(num / 1000000000).toFixed(1) + 'B'
	else if num >= 1000000
		(num / 1000000).toFixed(1) + 'M'
	else if num >= 1000
		(num / 1000).toFixed(1) + 'K'
	else
		num

class window.Dashing extends Batman.App
#		@root ->
# Dashing.params = Batman.URI.paramsFromQuery(window.location.search.slice(1));

class Dashing.Widget extends Batman.View
	constructor: ->
		# Set the view path
		@constructor::source = Batman.Filters.underscore(@constructor.name)
		super

		@observe 'node', (newValue, oldValue) ->
			
			if !oldValue && !@_registeredAtDashing
				@_registeredAtDashing = true
				@_nodeData = $(@node).data() if $(@node).data().id
								
				@_renderNode() 
				
	
	attachTo: (@el_id) =>
		@_nodeData = $(@el_id).data()
		
		if @node
			@_renderNode()
	
	_renderNode: () =>
		
		if @_nodeData
		
			console.log @node
			console.log @_nodeData
	
			$(@el_id).replaceWith($(@node)) if @el_id
			$(@node).data(@_nodeData)
			$(@node).attr('id', @el_id.slice(1)) if @el_id
			#@insertIntoDOM(document.getElementById(@el_id)) if @el_id
			
			
			@mixin(@_nodeData)
		
			Dashing.widgets[@id] ||= []
			Dashing.widgets[@id].push(@)

			# in case the events from the server came
			# before the widget was rendered
			@mixin(Dashing.lastEvents[@id]) 

			type = Batman.Filters.dashize(@constructor.name)
			$(@node).addClass("widget widget-#{type} #{@id}")
			
			@initializeBindings() if @el_id
		
		
		
		
	
	
	@accessor 'updatedAtMessage', ->
		if updatedAt = @get('updatedAt')
			timestamp = new Date(updatedAt * 1000)
			hours = timestamp.getHours()
			minutes = ("0" + timestamp.getMinutes()).slice(-2)
			"Last updated at #{hours}:#{minutes}"

	@::on 'ready', ->
		Dashing.Widget.fire 'ready'

	receiveData: (data) =>
		@mixin(data)
		@onData(data)

	onData: (data) =>
		# Widgets override this to handle incoming data

Dashing.AnimatedValue =
	get: Batman.Property.defaultAccessor.get
	set: (k, to) ->
		if !to? || isNaN(to)
			@[k] = to
		else
			timer = "interval_#{k}"
			num = if (!isNaN(@[k]) && @[k]?) then @[k] else 0
			unless @[timer] || num == to
				to = parseFloat(to)
				num = parseFloat(num)
				up = to > num
				num_interval = Math.abs(num - to) / 90
				@[timer] =
					setInterval =>
						num = if up then Math.ceil(num+num_interval) else Math.floor(num-num_interval)
						if (up && num > to) || (!up && num < to)
							num = to
							clearInterval(@[timer])
							@[timer] = null
							delete @[timer]
						@[k] = num
						@set k, to
					, 10
			@[k] = num

Dashing.widgets = widgets = {}
Dashing.lastEvents = lastEvents = {}
Dashing.debugMode = false

source = new EventSource('/dashing/events')
source.addEventListener 'open', (e) ->
	console.log("Connection opened", e)

source.addEventListener 'error', (e)->
	console.log("Connection error", e)
	if (e.currentTarget.readyState == EventSource.CLOSED)
		console.log("Connection closed")
		setTimeout (->
			window.location.reload()
		), 5 * 60 * 1000

source.addEventListener 'message', (e) =>
	data = JSON.parse(e.data)
	if lastEvents[data.id]?.updatedAt != data.updatedAt
		if Dashing.debugMode
			console.log("Received data for #{data.id}", data)
		lastEvents[data.id] = data
		if widgets[data.id]?.length > 0
			for widget in widgets[data.id]
				widget.receiveData(data)


$(document).ready ->
	Dashing.run()
