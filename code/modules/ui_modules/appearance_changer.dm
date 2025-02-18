/datum/ui_module/appearance_changer
	name = "Appearance Editor"
	available_to_ai = FALSE
	var/flags = APPEARANCE_ALL_HAIR
	var/mob/living/carbon/human/owner = null
	var/list/valid_species = list()
	var/list/valid_hairstyles = list()
	var/list/valid_facial_hairstyles = list()

	var/check_whitelist
	var/list/whitelist
	var/list/blacklist

/datum/ui_module/appearance_changer/New(var/location, var/mob/living/carbon/human/H, var/check_species_whitelist = 1, var/list/species_whitelist = list(), var/list/species_blacklist = list())
	..()
	owner = H
	src.check_whitelist = check_species_whitelist
	src.whitelist = species_whitelist
	src.blacklist = species_blacklist

/datum/ui_module/appearance_changer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	switch(action)
		if("race")
			if(can_change(APPEARANCE_RACE) && (params["race"] in valid_species))
				if(owner.change_species(params["race"]))
					cut_data()
					return TRUE
		if("gender")
			if(can_change(APPEARANCE_GENDER) && (params["gender"] in owner.species.genders))
				if(owner.change_gender(params["gender"]))
					cut_data()
					return TRUE
		if("skin_tone")
			if(can_change_skin_tone())
				var/new_s_tone = input(usr, "Choose your character's skin-tone:\n1 (lighter) - [owner.species.max_skin_tone()] (darker)", "Skin Tone", -owner.s_tone + 35) as num|null
				if(isnum(new_s_tone) && can_still_topic(state) && owner.species.appearance_flags & HAS_SKIN_TONE_NORMAL)
					new_s_tone = 35 - max(min(round(new_s_tone), owner.species.max_skin_tone()), 1)
					return owner.change_skin_tone(new_s_tone)
		if("skin_color")
			if(can_change_skin_color())
				var/new_skin = input(usr, "Choose your character's skin colour: ", "Skin Color", rgb(owner.r_skin, owner.g_skin, owner.b_skin)) as color|null
				if(new_skin && can_still_topic(state))
					var/r_skin = hex2num(copytext(new_skin, 2, 4))
					var/g_skin = hex2num(copytext(new_skin, 4, 6))
					var/b_skin = hex2num(copytext(new_skin, 6, 8))
					if(owner.change_skin_color(r_skin, g_skin, b_skin))
						update_dna()
						return TRUE
		if("hair")
			if(can_change(APPEARANCE_HAIR) && (params["hair"] in valid_hairstyles))
				if(owner.change_hair(params["hair"]))
					update_dna()
					return TRUE
		if("hair_color")
			if(can_change(APPEARANCE_HAIR_COLOR))
				var/new_hair = input("Please select hair color.", "Hair Color", rgb(owner.r_hair, owner.g_hair, owner.b_hair)) as color|null
				if(new_hair && can_still_topic(state))
					var/r_hair = hex2num(copytext(new_hair, 2, 4))
					var/g_hair = hex2num(copytext(new_hair, 4, 6))
					var/b_hair = hex2num(copytext(new_hair, 6, 8))
					if(owner.change_hair_color(r_hair, g_hair, b_hair))
						update_dna()
						return TRUE
		if("facial_hair")
			if(can_change(APPEARANCE_FACIAL_HAIR) && (params["facial_hair"] in valid_facial_hairstyles))
				if(owner.change_facial_hair(params["facial_hair"]))
					update_dna()
					return TRUE
		if("facial_hair_color")
			if(can_change(APPEARANCE_FACIAL_HAIR_COLOR))
				var/new_facial = input("Please select facial hair color.", "Facial Hair Color", rgb(owner.r_facial, owner.g_facial, owner.b_facial)) as color|null
				if(new_facial && can_still_topic(state))
					var/r_facial = hex2num(copytext(new_facial, 2, 4))
					var/g_facial = hex2num(copytext(new_facial, 4, 6))
					var/b_facial = hex2num(copytext(new_facial, 6, 8))
					if(owner.change_facial_hair_color(r_facial, g_facial, b_facial))
						update_dna()
						return TRUE
		if("eye_color")
			if(can_change(APPEARANCE_EYE_COLOR))
				var/new_eyes = input("Please select eye color.", "Eye Color", rgb(owner.r_eyes, owner.g_eyes, owner.b_eyes)) as color|null
				if(new_eyes && can_still_topic(state))
					var/r_eyes = hex2num(copytext(new_eyes, 2, 4))
					var/g_eyes = hex2num(copytext(new_eyes, 4, 6))
					var/b_eyes = hex2num(copytext(new_eyes, 6, 8))
					if(owner.change_eye_color(r_eyes, g_eyes, b_eyes))
						update_dna()
						return TRUE
	return FALSE

/datum/ui_module/appearance_changer/ui_state(mob/user)
	return ui_always_state()

/datum/ui_module/appearance_changer/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!owner || !owner.species)
		. = UI_CLOSE

/datum/ui_module/appearance_changer/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "AppearanceChanger")
		ui.open()

/datum/ui_module/appearance_changer/ui_data(mob/user)
	generate_data()

	var/list/data = host.initial_data()

	data["specimen"] = owner.species.name
	data["gender"] = owner.gender
	data["change_race"] = can_change(APPEARANCE_RACE)
	if(data["change_race"])
		var/species[0]
		for(var/specimen in valid_species)
			species[++species.len] =  list("specimen" = specimen)
		data["species"] = species

	data["change_gender"] = can_change(APPEARANCE_GENDER)
	if(data["change_gender"])
		var/genders[0]
		for(var/gender in owner.species.genders)
			genders[++genders.len] =  list("gender_name" = gender2text(gender), "gender_key" = gender)
		data["genders"] = genders
	data["change_skin_tone"] = can_change_skin_tone()
	data["change_skin_color"] = can_change_skin_color()
	data["change_eye_color"] = can_change(APPEARANCE_EYE_COLOR)
	data["change_hair"] = can_change(APPEARANCE_HAIR)
	if(data["change_hair"])
		var/hair_styles[0]
		for(var/hair_style in valid_hairstyles)
			hair_styles[++hair_styles.len] = list("hairstyle" = hair_style)
		data["hair_styles"] = hair_styles
		data["hair_style"] = owner.h_style

	data["change_facial_hair"] = can_change(APPEARANCE_FACIAL_HAIR)
	if(data["change_facial_hair"])
		var/facial_hair_styles[0]
		for(var/facial_hair_style in valid_facial_hairstyles)
			facial_hair_styles[++facial_hair_styles.len] = list("facialhairstyle" = facial_hair_style)
		data["facial_hair_styles"] = facial_hair_styles
		data["facial_hair_style"] = owner.f_style

	data["change_hair_color"] = can_change(APPEARANCE_HAIR_COLOR)
	data["change_facial_hair_color"] = can_change(APPEARANCE_FACIAL_HAIR_COLOR)

	return data

/datum/ui_module/appearance_changer/proc/update_dna()
	if(owner && (flags & APPEARANCE_UPDATE_DNA))
		owner.update_dna()

/datum/ui_module/appearance_changer/proc/can_change(var/flag)
	return owner && (flags & flag)

/datum/ui_module/appearance_changer/proc/can_change_skin_tone()
	return owner && (flags & APPEARANCE_SKIN) && owner.species.appearance_flags & HAS_A_SKIN_TONE

/datum/ui_module/appearance_changer/proc/can_change_skin_color()
	return owner && (flags & APPEARANCE_SKIN) && owner.species.appearance_flags & HAS_SKIN_COLOR

/datum/ui_module/appearance_changer/proc/cut_data()
	// These previously called Cut()... on lists that were passed by reference...
	// Bay coders give me trust issues sometimes.
	valid_hairstyles = null
	valid_facial_hairstyles = null

/datum/ui_module/appearance_changer/proc/generate_data()
	if(!owner)
		return
	if(!LAZY_LENGTH(valid_species))
		valid_species = owner.generate_valid_species(check_whitelist, whitelist, blacklist)
	if(!LAZY_LENGTH(valid_hairstyles))
		valid_hairstyles = owner.generate_valid_hairstyles()
	if(!LAZY_LENGTH(valid_facial_hairstyles))
		valid_facial_hairstyles = owner.generate_valid_facial_hairstyles()
