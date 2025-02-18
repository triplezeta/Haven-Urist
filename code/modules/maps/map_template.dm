/datum/map_template
	var/name = "Default Template Name"
	var/width = 0
	var/height = 0
	var/tallness = 0
	var/list/mappaths = null
	var/loaded = 0 // Times loaded this round
	var/list/shuttles_to_initialise = list()
	var/base_turf_for_zs = null
	var/accessibility_weight = 0
	var/template_flags = TEMPLATE_FLAG_ALLOW_DUPLICATES

/datum/map_template/New(var/path = null, var/list/paths = null, var/rename = null)
	if(path)
		paths = list()
		paths += path
	if(paths && !islist(paths))
		crash_with("Non-list paths passed into map template constructor.")
	if(paths)
		mappaths = paths
	if(mappaths)
		preload_size(mappaths)
//	if(path)
//		mappath = path
//		preload_size(mappath)
//	if(map)
//		mapfile = map
	if(rename)
		name = rename

/datum/map_template/proc/preload_size()
	var/list/bounds = list(1.#INF, 1.#INF, 1.#INF, -1.#INF, -1.#INF, -1.#INF)
	var/z_offset = 1 // needed to calculate z-bounds correctly
	for (var/mappath in mappaths)
		var/datum/map_load_metadata/M = maploader.load_map(file(mappath), 1, 1, z_offset, cropMap=FALSE, measureOnly=TRUE, no_changeturf=TRUE, clear_contents= template_flags & TEMPLATE_FLAG_CLEAR_CONTENTS)
		if(M)
			bounds = extend_bounds_if_needed(bounds, M.bounds)
			z_offset++
		else
			return FALSE
	width = bounds[MAP_MAXX] - bounds[MAP_MINX] + 1
	height = bounds[MAP_MAXY] - bounds[MAP_MINX] + 1
	tallness = bounds[MAP_MAXZ] - bounds[MAP_MINZ] + 1
	return TRUE

/datum/map_template/proc/init_atoms(var/list/atoms)
	if (SSatoms.initialized == INITIALIZATION_INSSATOMS)
		return // let proper initialisation handle it later
	if(length(shuttles_to_initialise))
		SSshuttle.suspend() // For proper shuttle init behavior, we wait until done with init here.
	atoms = atoms.Copy()

	var/list/turf/turfs = list()
	var/list/obj/machinery/atmospherics/atmos_machines = list()
	var/list/obj/machinery/machines = list()
	var/list/obj/structure/cable/cables = list()

	for(var/atom/A in atoms)
		if(istype(A, /turf))
			turfs += A
		if(istype(A, /obj/structure/cable))
			cables += A
		if(istype(A, /obj/machinery/atmospherics))
			atmos_machines += A
		if(istype(A, /obj/machinery))
			machines += A

	SSatoms.InitializeAtoms(atoms)

	SSmachines.setup_powernets_for_cables(cables)
	SSmachines.setup_atmos_machinery(atmos_machines)

	for (var/i in machines)
		var/obj/machinery/machine = i
		machine.power_change()

	for (var/i in turfs)
		var/turf/T = i
		T.post_change()
		if(template_flags & TEMPLATE_FLAG_NO_RUINS)
			T.turf_flags |= TURF_FLAG_NORUINS
		if(template_flags & TEMPLATE_FLAG_NO_RADS)
			qdel(SSradiation.sources_assoc[i])

/datum/map_template/proc/init_shuttles()
	for (var/shuttle_type in shuttles_to_initialise)
		SSshuttle.initialise_shuttle(shuttle_type)

/datum/map_template/proc/load_new_z()

	var/x = round((world.maxx - width)/2)
	var/y = round((world.maxy - height)/2)
	var/initial_z = world.maxz + 1

	if (x < 1) x = 1
	if (y < 1) y = 1

	var/list/bounds = list(1.#INF, 1.#INF, 1.#INF, -1.#INF, -1.#INF, -1.#INF)
	var/list/atoms_to_initialise = list()

	for (var/mappath in mappaths)
		var/datum/map_load_metadata/M = maploader.load_map(file(mappath), x, y, no_changeturf=TRUE)
		if (M)
			bounds = extend_bounds_if_needed(bounds, M.bounds)
			atoms_to_initialise += M.atoms_to_initialise
		else
			return FALSE

	for (var/z_index = bounds[MAP_MINZ]; z_index <= bounds[MAP_MAXZ]; z_index++)
		if (accessibility_weight)
			GLOB.using_map.accessible_z_levels[num2text(z_index)] = accessibility_weight
		if (base_turf_for_zs)
			GLOB.using_map.base_turf_by_z[num2text(z_index)] = base_turf_for_zs
		GLOB.using_map.player_levels |= z_index

	//initialize things that are normally initialized after map load
	init_atoms(atoms_to_initialise)
	init_shuttles()
	after_load(initial_z)
	for(var/light_z = initial_z to world.maxz)
		create_lighting_overlays_zlevel(light_z)
	log_game("Z-level [name] loaded at [x],[y],[world.maxz]")
	loaded++

	return locate(world.maxx/2, world.maxy/2, world.maxz)

/datum/map_template/proc/load(turf/T, centered=FALSE)
	if(centered)
		T = locate(T.x - round(width/2) , T.y - round(height/2) , T.z)
	if(!T)
		return
	if(T.x+width > world.maxx)
		return
	if(T.y+height > world.maxy)
		return

	var/list/atoms_to_initialise = list()

	for (var/mappath in mappaths)
		var/datum/map_load_metadata/M = maploader.load_map(file(mappath), T.x, T.y, T.z, cropMap=TRUE, clear_contents=(template_flags & TEMPLATE_FLAG_CLEAR_CONTENTS))
		if (M)
			atoms_to_initialise += M.atoms_to_initialise
		else
			return FALSE

	//initialize things that are normally initialized after map load
	init_atoms(atoms_to_initialise)
	init_shuttles()
	after_load(T.z)
	SSlighting.InitializeTurfs(atoms_to_initialise)	// Hopefully no turfs get placed on new coords by SSatoms.
	log_game("[name] loaded at at [T.x],[T.y],[T.z]")
	loaded++

	return TRUE

/datum/map_template/proc/after_load(z)
	return

/datum/map_template/proc/extend_bounds_if_needed(var/list/existing_bounds, var/list/new_bounds)
	var/list/bounds_to_combine = existing_bounds.Copy()
	for (var/min_bound in list(MAP_MINX, MAP_MINY, MAP_MINZ))
		bounds_to_combine[min_bound] = min(existing_bounds[min_bound], new_bounds[min_bound])
	for (var/max_bound in list(MAP_MAXX, MAP_MAXY, MAP_MAXZ))
		bounds_to_combine[max_bound] = max(existing_bounds[max_bound], new_bounds[max_bound])
	return bounds_to_combine


/datum/map_template/proc/get_affected_turfs(turf/T, centered = FALSE)
	var/turf/placement = T
	if(centered)
		var/turf/corner = locate(placement.x - round(width/2), placement.y - round(height/2), placement.z)
		if(corner)
			placement = corner
	return block(placement, locate(placement.x+width-1, placement.y+height-1, placement.z))

//for your ever biggening badminnery kevinz000
//? - Cyberboss
/proc/load_new_z_level(var/file, var/name)
	var/datum/map_template/template = new(file, name)
	template.load_new_z()
