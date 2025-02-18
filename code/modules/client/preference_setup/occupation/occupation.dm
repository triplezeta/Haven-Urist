#define JOB_LEVEL_NEVER  4
#define JOB_LEVEL_LOW    3
#define JOB_LEVEL_MEDIUM 2
#define JOB_LEVEL_HIGH   1

/datum/preferences
	//Since there can only be 1 high job.
	var/job_high = null
	var/list/job_medium        //List of all things selected for medium weight
	var/list/job_low           //List of all the things selected for low weight
	var/list/player_alt_titles // the default name of a job like "Medical Doctor"
	var/char_branch	= "None"   // military branch
	var/char_rank = "None"     // military rank

	//Keeps track of preferrence for not getting any wanted jobs
	var/alternate_option = 2

/datum/category_item/player_setup_item/occupation
	name = "Occupation"
	sort_order = 1
	var/datum/browser/panel

/datum/category_item/player_setup_item/occupation/load_character(var/savefile/S)
	from_file(S["alternate_option"], 	pref.alternate_option)
	from_file(S["job_high"],			pref.job_high)
	from_file(S["job_medium"],			pref.job_medium)
	from_file(S["job_low"],				pref.job_low)
	from_file(S["player_alt_titles"],	pref.player_alt_titles)

/datum/category_item/player_setup_item/occupation/save_character(var/savefile/S)
	to_file(S["alternate_option"],		pref.alternate_option)
	to_file(S["job_high"],				pref.job_high)
	to_file(S["job_medium"],			pref.job_medium)
	to_file(S["job_low"],				pref.job_low)
	to_file(S["player_alt_titles"],		pref.player_alt_titles)

/datum/category_item/player_setup_item/occupation/sanitize_character()
	if(!istype(pref.job_medium)) 		pref.job_medium = list()
	if(!istype(pref.job_low))    		pref.job_low = list()

	pref.alternate_option	= sanitize_integer(pref.alternate_option, 0, 2, initial(pref.alternate_option))
	pref.job_high	        = sanitize(pref.job_high, null)
	if(pref.job_medium && pref.job_medium.len)
		for(var/i in 1 to pref.job_medium.len)
			pref.job_medium[i]  = sanitize(pref.job_medium[i])
	if(pref.job_low && pref.job_low.len)
		for(var/i in 1 to pref.job_low.len)
			pref.job_low[i]  = sanitize(pref.job_low[i])
	if(!pref.player_alt_titles) pref.player_alt_titles = new()

	// We could have something like Captain set to high while on a non-rank map,
	// so we prune here to make sure we don't spawn as a PFC captain
	prune_occupation_prefs()

	var/jobs_by_type = decls_repository.get_decls(GLOB.using_map.allowed_jobs)
	for(var/job_type in jobs_by_type)
		var/datum/job/job = jobs_by_type[job_type]
		var/alt_title = pref.player_alt_titles[job.title]
		if(alt_title && !(alt_title in job.alt_titles))
			pref.player_alt_titles -= job.title

/datum/category_item/player_setup_item/occupation/content(mob/user, limit = 16, list/splitJobs, splitLimit = 1)
	if(!job_master)
		return

	var/datum/species/S = preference_species()

	. = list()
	. += "<tt><center>"
	. += "<b>Choose occupation chances.</b><br>Unavailable occupations are crossed out.<br>"
	. += "<br>"
	. += "<table width='100%' cellpadding='1' cellspacing='0'><tr><td width='20%'>" // Table within a table for alignment, also allows you to easily add more columns.
	. += "<table width='100%' cellpadding='1' cellspacing='0'>"
	var/index = -1
	if(splitLimit)
		limit = round((job_master.occupations.len+1)/2)

	//The job before the current job. I only use this to get the previous jobs color when I'm filling in blank rows.
	var/datum/job/lastJob
	for(var/datum/job/job in job_master.occupations)

		index += 1
		if((index >= limit) || (job.title in splitJobs))
			if((index < limit) && (lastJob != null))
				//If the cells were broken up by a job in the splitJob list then it will fill in the rest of the cells with
				//the last job's selection color. Creating a rather nice effect.
				for(var/i = 0, i < (limit - index), i += 1)
					. += "<tr bgcolor='[lastJob.selection_color]'><td width='40%' align='right'><a>&nbsp</a></td><td><a>&nbsp</a></td></tr>"
			. += "</table></td><td width='20%'><table width='100%' cellpadding='1' cellspacing='0'>"
			index = 0

		. += "<tr bgcolor='[job.selection_color]'><td width='40%' align='right'>"
		var/rank = job.title
		lastJob = job
		. += "<a href='?src=[REF(src)];job_info=[rank]'>\[?\]</a>"
		if(job.total_positions == 0 && job.spawn_positions == 0)
			. += "<del>[rank]</del></a></td><td><b> \[UNAVAILABLE]</b></td></tr>"
			continue
		if(jobban_isbanned(user, rank))
			. += "<del>[rank]</del></a></td><td><b> \[BANNED]</b></td></tr>"
			continue
		if(!job.player_old_enough(user.client))
			var/available_in_days = job.available_in_days(user.client)
			. += "<del>[rank]</del></a></td><td> \[IN [(available_in_days)] DAYS]</td></tr>"
			continue
		if(job.minimum_character_age && user.client && (user.client.prefs.age < job.minimum_character_age))
			. += "<del>[rank]</del></a></td><td> \[MINIMUM CHARACTER AGE: [job.minimum_character_age]]</td></tr>"
			continue

		if(!job.is_species_allowed(S))
			. += "<del>[rank]</del></a></td><td><b> \[SPECIES RESTRICTED]</b></td></tr>"
			continue

		if(("Assistant" in pref.job_low) && (rank != "Assistant"))
			. += "<font color=grey>[rank]</font></a></td><td></td></tr>"
			continue
		if((rank in GLOB.command_positions) || (rank == "AI"))//Bold head jobs
			. += "<b>[rank]</b>"
		else
			. += "[rank]"

		. += "</a></td><td width='40%'>"

		if(rank == "Assistant")//Assistant is special
			. += "<a href='?src=[REF(src)];set_job=[rank];set_level=[JOB_LEVEL_LOW]'>"
			. += " [rank in pref.job_low ? "<font color=55cc55>" : ""]\[Yes][rank in pref.job_low ? "</font>" : ""]"
			. += "</a>"
			. += "<a href='?src=[REF(src)];set_job=[rank];set_level=[JOB_LEVEL_NEVER]'>"
			. += " [!(rank in pref.job_low) ? "<font color=black>" : ""]\[No][!(rank in pref.job_low) ? "</font>" : ""]"
			. += "</a>"
		else
			var/current_level = JOB_LEVEL_NEVER
			if(pref.job_high == job.title)
				current_level = JOB_LEVEL_HIGH
			else if(job.title in pref.job_medium)
				current_level = JOB_LEVEL_MEDIUM
			else if(job.title in pref.job_low)
				current_level = JOB_LEVEL_LOW

			. += " <a href='?src=[REF(src)];set_job=[rank];set_level=[JOB_LEVEL_HIGH]'>[current_level == JOB_LEVEL_HIGH ? "<font color=55cc55>" : ""]\[High][current_level == JOB_LEVEL_HIGH ? "</font>" : ""]</a>"
			. += " <a href='?src=[REF(src)];set_job=[rank];set_level=[JOB_LEVEL_MEDIUM]'>[current_level == JOB_LEVEL_MEDIUM ? "<font color=eecc22>" : ""]\[Medium][current_level == JOB_LEVEL_MEDIUM ? "</font>" : ""]</a>"
			. += " <a href='?src=[REF(src)];set_job=[rank];set_level=[JOB_LEVEL_LOW]'>[current_level == JOB_LEVEL_LOW ? "<font color=cc5555>" : ""]\[Low][current_level == JOB_LEVEL_LOW ? "</font>" : ""]</a>"
			. += " <a href='?src=[REF(src)];set_job=[rank];set_level=[JOB_LEVEL_NEVER]'>[current_level == JOB_LEVEL_NEVER ? "<font color=black>" : ""]\[NEVER][current_level == JOB_LEVEL_NEVER ? "</font>" : ""]</a>"

		if(job.alt_titles)
			. += "</td></tr><tr bgcolor='[lastJob.selection_color]'><td width='40%' align='center'>&nbsp</td><td><a href='?src=[REF(src)];select_alt_title=[REF(job)]'>\[[pref.GetPlayerAltTitle(job)]\]</a></td></tr>"
		. += "</td></tr>"
	. += "</td'></tr></table>"
	. += "</center></table><center>"

	switch(pref.alternate_option)
		if(GET_RANDOM_JOB)
			. += "<u><a href='?src=[REF(src)];job_alternative=1'>Get random job if preferences unavailable</a></u>"
		if(BE_ASSISTANT)
			. += "<u><a href='?src=[REF(src)];job_alternative=1'>Be assistant if preference unavailable</a></u>"
		if(RETURN_TO_LOBBY)
			. += "<u><a href='?src=[REF(src)];job_alternative=1'>Return to lobby if preference unavailable</a></u>"

	. += "<a href='?src=[REF(src)];reset_jobs=1'>\[Reset\]</a></center>"
	. += "</tt>"
	. = jointext(.,null)

/datum/category_item/player_setup_item/occupation/OnTopic(href, href_list, user)
	if(href_list["reset_jobs"])
		ResetJobs()
		return TRUE

	else if(href_list["job_alternative"])
		if(pref.alternate_option == GET_RANDOM_JOB || pref.alternate_option == BE_ASSISTANT)
			pref.alternate_option += 1
		else if(pref.alternate_option == RETURN_TO_LOBBY)
			pref.alternate_option = 0
		return TRUE

	else if(href_list["select_alt_title"])
		var/datum/job/job = locate(href_list["select_alt_title"])
		if (job)
			var/choices = list(job.title) + job.alt_titles
			var/choice = input("Choose an title for [job.title].", "Choose Title", pref.GetPlayerAltTitle(job)) as anything in choices|null
			if(choice && CanUseTopic(user))
				SetPlayerAltTitle(job, choice)
				return (pref.equip_preview_mob ? UPDATE_PREVIEW : TRUE)

	else if(href_list["set_job"] && href_list["set_level"])
		if(SetJob(user, href_list["set_job"], text2num(href_list["set_level"]))) return (pref.equip_preview_mob ? UPDATE_PREVIEW : TRUE)

	else if(href_list["job_info"])
		var/rank = href_list["job_info"]
		var/datum/job/job = job_master.GetJob(rank)
		var/dat = list()

		dat += "<p style='background-color: [job.selection_color]'><br><br><p>"
		if(job.alt_titles)
			dat += "<i><b>Alternative titles:</b> [english_list(job.alt_titles)].</i>"
		send_rsc(user, job.get_job_icon(), "job[ckey(rank)].png")
		dat += "<img src=job[ckey(rank)].png width=96 height=96 style='float:left;'>"
		if(job.department)
			dat += "<b>Department:</b> [job.department]."
			if(job.head_position)
				dat += "You are in charge of this department."

		dat += "You answer to <b>[job.supervisors]</b> normally."

		dat += "<hr style='clear:left;'>"
		if(config.wikiurl)
			dat += "<a href='?src=[REF(src)];job_wiki=[rank]'>Open wiki page in browser</a>"
		var/description = job.get_description_blurb()
		if(description)
			dat += html_encode(description)
		var/datum/browser/popup = new(user, "Job Info", "[capitalize(rank)]", 430, 520, src)
		popup.set_content(jointext(dat,"<br>"))
		popup.open()

	else if(href_list["job_wiki"])
		var/rank = href_list["job_wiki"]
		open_link(user,"[config.wikiurl][rank]")

	return ..()

/datum/category_item/player_setup_item/occupation/proc/SetPlayerAltTitle(datum/job/job, new_title)
	// remove existing entry
	pref.player_alt_titles -= job.title
	// add one if it's not default
	if(job.title != new_title)
		pref.player_alt_titles[job.title] = new_title

/datum/category_item/player_setup_item/occupation/proc/SetJob(mob/user, role, level)
	var/datum/job/job = job_master.GetJob(role)
	if(!job)
		return 0

	if(role == "Assistant")
		if(level == JOB_LEVEL_NEVER)
			pref.job_low -= job.title
		else
			pref.job_low |= job.title
		return 1

	SetJobDepartment(job, level)

	return 1

/datum/category_item/player_setup_item/occupation/proc/SetJobDepartment(var/datum/job/job, var/level)
	if(!job || !level)	return 0

	var/current_level = JOB_LEVEL_NEVER
	if(pref.job_high == job.title)
		current_level = JOB_LEVEL_HIGH
	else if(job.title in pref.job_medium)
		current_level = JOB_LEVEL_MEDIUM
	else if(job.title in pref.job_low)
		current_level = JOB_LEVEL_LOW

	switch(current_level)
		if(JOB_LEVEL_HIGH)
			pref.job_high = null
		if(JOB_LEVEL_MEDIUM)
			pref.job_medium -= job.title
		if(JOB_LEVEL_LOW)
			pref.job_low -= job.title

	switch(level)
		if(JOB_LEVEL_HIGH)
			if(pref.job_high)
				pref.job_medium |= pref.job_high
			pref.job_high = job.title
		if(JOB_LEVEL_MEDIUM)
			pref.job_medium |= job.title
		if(JOB_LEVEL_LOW)
			pref.job_low |= job.title

	return 1

/datum/preferences/proc/CorrectLevel(var/datum/job/job, var/level)
	if(!job || !level)	return 0
	switch(level)
		if(1)
			return job_high == job.title
		if(2)
			return !!(job.title in job_medium)
		if(3)
			return !!(job.title in job_low)
	return 0

/**
 *  Prune a player's job preferences based on current branch, rank and species
 *
 *  This proc goes through all the preferred jobs, and removes the ones incompatible with current rank or branch.
 */
/datum/category_item/player_setup_item/proc/prune_job_prefs()
	var/allowed_titles = list()
	var/jobs_by_type = decls_repository.get_decls(GLOB.using_map.allowed_jobs)
	for(var/job_type in jobs_by_type)
		var/datum/job/job = jobs_by_type[job_type]
		allowed_titles += job.title

		if(job.title == pref.job_high)
			if(job.is_restricted(pref))
				pref.job_high = null

		else if(job.title in pref.job_medium)
			if(job.is_restricted(pref))
				pref.job_medium.Remove(job.title)

		else if(job.title in pref.job_low)
			if(job.is_restricted(pref))
				pref.job_low.Remove(job.title)

	if(pref.job_high && !(pref.job_high in allowed_titles))
		pref.job_high = null

	for(var/job_title in pref.job_medium)
		if(!(job_title in allowed_titles))
			pref.job_medium -= job_title

	for(var/job_title in pref.job_low)
		if(!(job_title in allowed_titles))
			pref.job_low -= job_title

/datum/category_item/player_setup_item/proc/prune_occupation_prefs()
	prune_job_prefs()

/datum/category_item/player_setup_item/occupation/proc/ResetJobs()
	pref.job_high = null
	pref.job_medium = list()
	pref.job_low = list()

	pref.player_alt_titles.Cut()

/datum/preferences/proc/GetPlayerAltTitle(datum/job/job)
	return (job.title in player_alt_titles) ? player_alt_titles[job.title] : job.title

#undef JOB_LEVEL_NEVER
#undef JOB_LEVEL_LOW
#undef JOB_LEVEL_MEDIUM
#undef JOB_LEVEL_HIGH
