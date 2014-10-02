root = exports ? this

Network = () ->
  # variables we want to access
  # in multiple places of Network
  width = 960
  height = 800
  # allData will store the unfiltered data
  allData = []
  curLinksData = []
  curNodesData = []
  linkedByIndex = {}
  # these will hold the svg groups for
  # accessing the nodes and links display
  nodesG = null
  linksG = null
  # these will point to the circles and lines
  # of the nodes and links
  node = null
  link = null
  # variables to refect the current settings
  # of the visualization
  layout = "force"
  filter = "all"
  sort = "songs"

  # our force directed layout
  force = d3.layout.force()

  # color function used to color nodes
  nodeColors = (party) ->
    if party == "Democrat"
      '#4273ED'
    else
      '#ED434B'

  # tooltip used to display details
  tooltip = Tooltip("vis-tooltip", 230)

  # charge used in artist layout
  charge = (node) -> -Math.pow(node.radius, 2.0) / 2

  # Starting point for network visualization
  # Initializes visualization and starts force layout
  network = (selection, data) ->
    # format our data
    allData = setupData(data)

    # create our svg and groups
    vis = d3.select(selection).append("svg")
      .attr("width", width)
      .attr("height", height)
    linksG = vis.append("g").attr("id", "links")
    nodesG = vis.append("g").attr("id", "nodes")

    # setup the size of the force environment
    force.size([width, height])

    setLayout("force")

    # perform rendering and start force layout
    update()

  # The update() function performs the bulk of the
  # work to setup our visualization based on the
  # current layout/sort/filter.
  #
  # update() is called everytime a parameter changes
  # and the network needs to be reset.
  update = () ->
    # filter data to show based on current filter settings.
    curNodesData = filterNodes(allData.nodes)
    curLinksData = filterLinks(allData.links, curNodesData)

    # reset nodes in force layout
    force.nodes(curNodesData)

    # enter / exit for nodes
    updateNodes()

    # always show links in force layout
    if layout == "force"
      force.links(curLinksData)
      updateLinks()
    else
      # reset links so they do not interfere with
      # other layouts. updateLinks() will be called when
      # force is done animating.
      force.links([])
      # if present, remove them from svg
      if link
        link.data([]).exit().remove()
        link = null

    # start me up!
    force.start()

  network.updateData = (newData) ->
    allData = setupData(newData)
    link.remove()
    node.remove()
    update()

  # called once to clean up raw data and switch links to
  # point to node instances
  # Returns modified data
  setupData = (data) ->
    # initialize circle radius scale
    #countExtent = d3.extent(data.nodes, (d) -> d.playcount)
    #circleRadius = d3.scale.sqrt().range([3, 12]).domain(countExtent)
    #circleRadius = 5

    data.nodes.forEach (n) ->
      # set initial x/y to values within the width/height
      # of the visualization
      n.x = randomnumber=Math.floor(Math.random()*width)
      n.y = randomnumber=Math.floor(Math.random()*height)
      # add radius to the node so we can use it later
      n.radius = 5

    # id's -> node objects
    nodesMap  = mapNodes(data.nodes)

    # switch links to point to node objects instead of id's
    data.links.forEach (l) ->
      l.source = nodesMap.get(l.source)
      l.target = nodesMap.get(l.target)

      # linkedByIndex is used for link sorting
      linkedByIndex["#{l.source.id},#{l.target.id}"] = 1

    data

  # Helper function to map node id's to node objects.
  # Returns d3.map of ids -> nodes
  mapNodes = (nodes) ->
    nodesMap = d3.map()
    nodes.forEach (n) ->
      nodesMap.set(n.id, n)
    nodesMap

  # Helper function that returns an associative array
  # with counts of unique attr in nodes
  # attr is value stored in node, like 'artist'
  nodeCounts = (nodes, attr) ->
    counts = {}
    nodes.forEach (d) ->
      counts[d[attr]] ?= 0
      counts[d[attr]] += 1
    counts

  # Given two nodes a and b, returns true if
  # there is a link between them.
  # Uses linkedByIndex initialized in setupData
  neighboring = (a, b) ->
    linkedByIndex[a.id + "," + b.id] or
      linkedByIndex[b.id + "," + a.id]

  # Removes nodes from input array
  # based on current filter setting.
  # Returns array of nodes
  filterNodes = (allNodes) ->
    filteredNodes = allNodes
    if filter == "popular" or filter == "obscure"
      playcounts = allNodes.map((d) -> d.playcount).sort(d3.ascending)
      cutoff = d3.quantile(playcounts, 0.5)
      filteredNodes = allNodes.filter (n) ->
        if filter == "popular"
          n.playcount > cutoff
        else if filter == "obscure"
          n.playcount <= cutoff

    filteredNodes

  # Returns array of artists sorted based on
  # current sorting method.
  sortedArtists = (nodes,links) ->
    artists = []
    if sort == "links"
      counts = {}
      links.forEach (l) ->
        counts[l.source.artist] ?= 0
        counts[l.source.artist] += 1
        counts[l.target.artist] ?= 0
        counts[l.target.artist] += 1
      # add any missing artists that dont have any links
      nodes.forEach (n) ->
        counts[n.artist] ?= 0

      # sort based on counts
      artists = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      # get just names
      artists = artists.map (v) -> v.key
    else
      # sort artists by song count
      counts = nodeCounts(nodes, "artist")
      artists = d3.entries(counts).sort (a,b) ->
        b.value - a.value
      artists = artists.map (v) -> v.key

    artists

  # Removes links from allLinks whose
  # source or target is not present in curNodes
  # Returns array of links
  filterLinks = (allLinks, curNodes) ->
    curNodes = mapNodes(curNodes)
    allLinks.filter (l) ->
      curNodes.get(l.source.id) and curNodes.get(l.target.id)

  # enter/exit display for nodes
  updateNodes = () ->
    node = nodesG.selectAll("circle.node")
      .data(curNodesData, (d) -> d.id)

    node.enter().append("circle")
      .attr("class", "node")
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)
      .attr("r", (d) -> d.radius)
      .style("fill", (d) -> nodeColors(d.party))
      .style("stroke", (d) -> strokeFor(d))
      .style("stroke-width", 1.0)

    node.on("mouseover", showDetails)
      .on("mouseout", hideDetails)

    node.exit().remove()

  # enter/exit display for links
  updateLinks = () ->
    link = linksG.selectAll("line.link")
      .data(curLinksData, (d) -> "#{d.source.id}_#{d.target.id}")
    link.enter().append("line")
      .attr("class", "link")
      .attr("stroke", "#ddd")
      .attr("stroke-opacity", 0.8)
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

    link.exit().remove()

  # switches force to new layout parameters
  setLayout = (newLayout) ->
    layout = newLayout
    force.on("tick", forceTick)
      .charge(-200)
      .linkDistance(50)

  # tick function for force directed layout
  forceTick = (e) ->
    node
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)

    link
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

  # Helper function that returns stroke color for
  # particular node.
  strokeFor = (d) ->
    d3.rgb(nodeColors(d.artist)).darker().toString()

  # Mouseover tooltip function
  showDetails = (d,i) ->
    content = '<p class="main">' + d.name + '</span></p>'
    content += '<hr class="tooltip-hr">'
    content += '<p class="main">' + d.party + '</span></p>'
    tooltip.showTooltip(content,d3.event)

    # higlight connected links
    if link
      link.attr("stroke", (l) ->
        if l.source == d or l.target == d then "#555" else "#ddd"
      )
        .attr("stroke-opacity", (l) ->
          if l.source == d or l.target == d then 1.0 else 0.5
        )

      # link.each (l) ->
      #   if l.source == d or l.target == d
      #     d3.select(this).attr("stroke", "#555")

    # highlight neighboring nodes
    # watch out - don't mess with node if search is currently matching
    node.style("stroke", (n) ->
      if (n.searched or neighboring(d, n)) then "#555" else strokeFor(n))
      .style("stroke-width", (n) ->
        if (n.searched or neighboring(d, n)) then 2.0 else 1.0)

    # highlight the node being moused over
    d3.select(this).style("stroke","black")
      .style("stroke-width", 2.0)

  # Mouseout function
  hideDetails = (d,i) ->
    tooltip.hideTooltip()
    # watch out - don't mess with node if search is currently matching
    node.style("stroke", (n) -> if !n.searched then strokeFor(n) else "#555")
      .style("stroke-width", (n) -> if !n.searched then 1.0 else 2.0)
    if link
      link.attr("stroke", "#ddd")
        .attr("stroke-opacity", 0.8)

  # Final act of Network() function is to return the inner 'network()' function.
  return network

# Activate selector button
activate = (group, link) ->
  d3.selectAll("##{group} a").classed("active", false)
  d3.select("##{group} ##{link}").classed("active", true)

$ ->
  myNetwork = Network()

  $("#song_select").on "change", (e) ->
    songFile = $(this).val()
    d3.json "data/#{songFile}", (json) ->
      myNetwork.updateData(json)

  d3.json "data/30/protection-and-affordable-care.json", (json) ->
    myNetwork("#vis", json)
