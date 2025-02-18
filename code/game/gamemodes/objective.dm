//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31
var/global/list/all_objectives = list()

/datum/objective
	var/datum/mind/owner = null			//Who owns the objective.
	var/explanation_text = "Nothing"	//What that person is supposed to do.
	var/datum/mind/target = null		//If they are focused on a particular person.
	var/target_amount = 0				//If they are focused on a particular number. Steal objectives have their own counter.
	var/completed = 0					//currently only used for custom objectives.

/datum/objective/New(var/text)
	all_objectives |= src
	if(text)
		explanation_text = text
	..()

/datum/objective/Destroy()
	all_objectives -= src
	..()

/datum/objective/proc/check_completion()
	return completed

/datum/objective/proc/find_target()
	var/list/possible_targets = list()
	for(var/datum/mind/possible_target in SSticker.minds)
		if(possible_target != owner && ishuman(possible_target.current) && (possible_target.current.stat != 2))
			possible_targets += possible_target
	if(possible_targets.len > 0)
		target = pick(possible_targets)


/datum/objective/proc/find_target_by_role(role, role_type=0)//Option sets either to check assigned role or special role. Default to assigned.
	for(var/datum/mind/possible_target in SSticker.minds)
		if((possible_target != owner) && ishuman(possible_target.current) && ((role_type ? possible_target.special_role : possible_target.assigned_role) == role) )
			target = possible_target
			break



/datum/objective/assassinate
/datum/objective/assassinate/find_target()
	..()
	if(target && target.current)
		explanation_text = "Assassinate [target.current.real_name], the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/assassinate/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Assassinate [target.current.real_name], the [!role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/assassinate/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD || issilicon(target.current) || isbrain(target.current) || target.current.z > 6 || !target.current.ckey) //Borgs/brains/AIs count as dead for traitor objectives. --NeoFite
			return 1
		return 0
	return 1


/datum/objective/anti_revolution/execute
/datum/objective/anti_revolution/execute/find_target()
	..()
	if(target && target.current)
		explanation_text = "[target.current.real_name], the [target.assigned_role] has extracted confidential information above their clearance. Execute \him[target.current]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/anti_revolution/execute/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "[target.current.real_name], the [!role_type ? target.assigned_role : target.special_role] has extracted confidential information above their clearance. Execute \him[target.current]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/anti_revolution/execute/check_completion()
	if(target && target.current)
		if(target.current.stat == DEAD || !ishuman(target.current))
			return 1
		return 0
	return 1

/datum/objective/anti_revolution/brig
var/already_completed = 0

/datum/objective/anti_revolution/brig/find_target()
	..()
	if(target && target.current)
		explanation_text = "Brig [target.current.real_name], the [target.assigned_role] for 20 minutes to set an example."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/anti_revolution/brig/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Brig [target.current.real_name], the [!role_type ? target.assigned_role : target.special_role] for 20 minutes to set an example."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/anti_revolution/brig/check_completion()
	if(already_completed)
		return 1

	if(target && target.current)
		if(target.current.stat == DEAD)
			return 0
		if(target.is_brigged(10 * 60 * 10))
			already_completed = 1
			return 1
		return 0
	return 0

/datum/objective/anti_revolution/demote/find_target()
	..()
	if(target && target.current)
		explanation_text = "[target.current.real_name], the [target.assigned_role]  has been classified as harmful to [GLOB.using_map.company_name]'s goals. Demote \him[target.current] to assistant."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/anti_revolution/demote/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "[target.current.real_name], the [!role_type ? target.assigned_role : target.special_role] has been classified as harmful to [GLOB.using_map.company_name]'s goals. Demote \him[target.current] to assistant."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/anti_revolution/demote/check_completion()
	if(target && target.current && istype(target,/mob/living/carbon/human))
		var/obj/item/weapon/card/id/I = target.current.GetIdCard()

		if(!istype(I)) return 1

		if(I.assignment == "Assistant")
			return 1
		else
			return 0
	return 1

/datum/objective/debrain //I want braaaainssss
/datum/objective/debrain/find_target()
	..()
	if(target && target.current)
		explanation_text = "Steal the brain of [target.current.real_name]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/debrain/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Steal the brain of [target.current.real_name] the [!role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/debrain/check_completion()
	if(!target)//If it's a free objective.
		return 1
	if( !owner.current || owner.current.stat==DEAD )//If you're otherwise dead.
		return 0
	if( !target.current || !isbrain(target.current) )
		return 0
	var/atom/A = target.current
	while(A.loc)			//check to see if the brainmob is on our person
		A = A.loc
		if(A == owner.current)
			return 1
	return 0


/datum/objective/protect //The opposite of killing a dude.
/datum/objective/protect/find_target()
	..()
	if(target && target.current)
		explanation_text = "Protect [target.current.real_name], the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/protect/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Protect [target.current.real_name], the [!role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/protect/check_completion()
	if(!target)			//If it's a free objective.
		return 1
	if(target.current)
		if(target.current.stat == DEAD || issilicon(target.current) || isbrain(target.current))
			return 0
		return 1
	return 0


/datum/objective/hijack
	explanation_text = "Hijack a pod by escaping alone."

/datum/objective/hijack/check_completion()
	if(!owner.current || owner.current.stat)
		return 0
	if(!evacuation_controller.has_evacuated())
		return 0
	if(issilicon(owner.current))
		return 0

	var/area/shuttle/shuttle_area = get_area(owner.current)
	if(!istype(shuttle_area) || !(shuttle_area.z in GLOB.using_map.admin_levels))
		return 0

	for(var/mob/living/player in GLOB.player_list)
		if(is_type_in_list(player.type, list(/mob/living/silicon/ai, /mob/living/silicon/pai)))
			continue
		if (!player.mind || player.mind == owner)
			continue
		if(get_area(player) == shuttle_area)
			return 0
	return 1

/datum/objective/silence
	explanation_text = "Do not allow anyone to escape.  Only allow the shuttle to be called when everyone is dead and your story is the only one left."

/datum/objective/silence/check_completion()
	if(!evacuation_controller.has_evacuated())
		return 0

	for(var/mob/living/player in GLOB.player_list)
		if(player == owner.current)
			continue
		if(player.mind)
			if(player.stat != DEAD)
				var/turf/T = get_turf(player)
				if(T && is_type_in_list(T.loc, GLOB.using_map.post_round_safe_areas))
					return 0
	return 1

/datum/objective/escape
	explanation_text = "Escape on the shuttle or an escape pod alive and free."


/datum/objective/escape/check_completion()
	if(issilicon(owner.current))
		return 0
	if(isbrain(owner.current))
		return 0
	if(!evacuation_controller.has_evacuated())
		return 0
	if(!owner.current || owner.current.stat ==2)
		return 0
	var/turf/location = get_turf(owner.current.loc)
	if(!location)
		return 0

	//Fails traitors if they are in a shuttle but knocked out or cuffed.
	if(owner.current.incapacitated(INCAPACITATION_KNOCKOUT|INCAPACITATION_RESTRAINED))
		return 0

	var/area/check_area = location.loc
	return check_area && is_type_in_list(check_area, GLOB.using_map.post_round_safe_areas)



/datum/objective/survive
	explanation_text = "Stay alive until the end."

/datum/objective/survive/check_completion()
	if(!owner.current || owner.current.stat == DEAD || isbrain(owner.current))
		return 0		//Brains no longer win survive objectives. --NEO
	if(issilicon(owner.current) && owner.current != owner.original)
		return 0
	return 1


// Similar to the anti-rev objective, but for traitors
/datum/objective/brig
	var/already_completed = 0

/datum/objective/brig/find_target()
	..()
	if(target && target.current)
		explanation_text = "Have [target.current.real_name], the [target.assigned_role] brigged for 10 minutes."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/brig/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Have [target.current.real_name], the [!role_type ? target.assigned_role : target.special_role] brigged for 10 minutes."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/brig/check_completion()
	if(already_completed)
		return 1

	if(target && target.current)
		if(target.current.stat == DEAD)
			return 0
		// Make the actual required time a bit shorter than the official time
		if(target.is_brigged(10 * 60 * 5))
			already_completed = 1
			return 1
		return 0
	return 0

// Harm a crew member, making an example of them
/datum/objective/harm
	var/already_completed = 0

/datum/objective/harm/find_target()
	..()
	if(target && target.current)
		explanation_text = "Make an example of [target.current.real_name], the [target.assigned_role]. Break one of their bones, detach one of their limbs or disfigure their face. Make sure they're alive when you do it."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/harm/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Make an example of [target.current.real_name], the [!role_type ? target.assigned_role : target.special_role]. Break one of their bones, detach one of their limbs or disfigure their face. Make sure they're alive when you do it."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/harm/check_completion()
	if(already_completed)
		return 1

	if(target && target.current && istype(target.current, /mob/living/carbon/human))
		if(target.current.stat == DEAD)
			return 0

		var/mob/living/carbon/human/H = target.current
		for(var/obj/item/organ/external/E in H.organs)
			if(E.status & ORGAN_BROKEN)
				return 1
		for(var/limb_tag in H.species.has_limbs) //todo check prefs for robotic limbs and amputations.
			var/list/organ_data = H.species.has_limbs[limb_tag]
			var/limb_type = organ_data["path"]
			var/found
			for(var/obj/item/organ/external/E in H.organs)
				if(limb_type == E.type)
					found = 1
					break
			if(!found)
				return 1

		var/obj/item/organ/external/head/head = H.get_organ(BP_HEAD)
		if(!head || (head.status & ORGAN_DISFIGURED))
			return 1
	return 0


/datum/objective/nuclear
	explanation_text = "Cause mass destruction with a nuclear device."



/datum/objective/steal
	var/obj/item/steal_target
	var/target_name

	var/global/possible_items[] = list(
		"the captain's antique laser gun" = /obj/item/weapon/gun/energy/captain,
		"a captain's jumpsuit" = /obj/item/clothing/under/rank/captain,
		"a functional AI" = /obj/item/weapon/aicard,
		"the [station_name()] blueprints" = /obj/item/blueprints,
		"a piece of corgi meat" = /obj/item/weapon/reagent_containers/food/snacks/meat/corgi,
		"a research director's jumpsuit" = /obj/item/clothing/under/rank/research_director,
		"a senior engineer's jumpsuit" = /obj/item/clothing/under/rank/chief_engineer,
		"a head of security's jumpsuit" = /obj/item/clothing/under/rank/head_of_security,
		"a head of personnel's jumpsuit" = /obj/item/clothing/under/rank/head_of_personnel,
		"the captain's pinpointer" = /obj/item/weapon/pinpointer
	)

	var/global/possible_items_special[] = list(
		/*"nuclear authentication disk" = /obj/item/weapon/disk/nuclear,*///Broken with the change to nuke disk making it respawn on z level change.
		"advanced energy gun" = /obj/item/weapon/gun/energy/gun/nuclear,
		"diamond drill" = /obj/item/weapon/pickaxe/diamonddrill,
		"bag of holding" = /obj/item/weapon/storage/backpack/holding,
		"hyper-capacity cell" = /obj/item/weapon/cell/hyper
	)


/datum/objective/steal/proc/set_target(item_name)
	target_name = item_name
	steal_target = possible_items[target_name]
	if (!steal_target )
		steal_target = possible_items_special[target_name]
	explanation_text = "Steal [target_name]."
	return steal_target


/datum/objective/steal/find_target()
	return set_target(pick(possible_items))


/datum/objective/steal/proc/select_target()
	var/list/possible_items_all = possible_items+possible_items_special+"custom"
	var/new_target = input("Select target:", "Objective target", steal_target) as null|anything in possible_items_all
	if (!new_target) return
	if (new_target == "custom")
		var/obj/item/custom_target = input("Select type:","Type") as null|anything in typesof(/obj/item)
		if (!custom_target) return
		var/tmp_obj = new custom_target
		var/custom_name = tmp_obj:name
		qdel(tmp_obj)
		custom_name = sanitize(input("Enter target name:", "Objective target", custom_name) as text|null)
		if (!custom_name) return
		target_name = custom_name
		steal_target = custom_target
		explanation_text = "Steal [target_name]."
	else
		set_target(new_target)
	return steal_target

/datum/objective/steal/check_completion()
	if(!steal_target || !owner.current)	return 0
	if(!isliving(owner.current))	return 0
	var/list/all_items = owner.current.get_contents()
	switch (target_name)
		if("a functional AI")
			for(var/mob/living/silicon/ai/ai in SSmobs.mob_list)
				if(ai.stat == DEAD)
					continue
				var/turf/T = get_turf(ai)
				if(owner.current.contains(ai) || (T && is_type_in_list(T.loc, GLOB.using_map.post_round_safe_areas)))
					return 1
		else

			for(var/obj/I in all_items) //Check for items
				if(istype(I, steal_target))
					return 1
	return 0


/datum/objective/download
/datum/objective/download/proc/gen_amount_goal()
	target_amount = rand(10,20)
	explanation_text = "Download [target_amount] research levels."
	return target_amount


/datum/objective/download/check_completion()
	if(!ishuman(owner.current))
		return 0
	if(!owner.current || owner.current.stat == 2)
		return 0

	var/current_amount
	var/obj/item/weapon/rig/S
	if(istype(owner.current,/mob/living/carbon/human))
		var/mob/living/carbon/human/H = owner.current
		S = H.back

	if(!istype(S) || !S.installed_modules || !S.installed_modules.len)
		return 0

	var/obj/item/rig_module/datajack/stolen_data = locate() in S.installed_modules
	if(!istype(stolen_data))
		return 0

	for(var/datum/tech/current_data in stolen_data.stored_research)
		if(current_data.level > 1)
			current_amount += (current_data.level-1)

	return (current_amount<target_amount) ? 0 : 1

/datum/objective/capture
/datum/objective/capture/proc/gen_amount_goal()
	target_amount = rand(5,10)
	explanation_text = "Accumulate [target_amount] capture points."
	return target_amount


/datum/objective/capture/check_completion()//Basically runs through all the mobs in the area to determine how much they are worth.
	var/captured_amount = 0
	var/area/centcom/holding/A = locate()

	for(var/mob/living/carbon/human/M in A) // Humans (and subtypes).
		var/worth = M.species.rarity_value
		if(M.stat==DEAD)//Dead folks are worth less.
			worth*=0.5
			continue
		captured_amount += worth

	for(var/mob/living/carbon/alien/larva/M in A)//Larva are important for research.
		if(M.stat==DEAD)
			captured_amount+=0.5
			continue
		captured_amount+=1


	if(captured_amount<target_amount)
		return 0
	return 1

// Heist objectives.
/datum/objective/heist
/datum/objective/heist/proc/choose_target()
		return

/datum/objective/heist/kidnap
/datum/objective/heist/kidnap/choose_target()
	var/list/roles = list("Chief Engineer","Research Director","Roboticist","Chemist","Engineer")
	var/list/possible_targets = list()
	var/list/priority_targets = list()

	for(var/datum/mind/possible_target in SSticker.minds)
		if(possible_target != owner && ishuman(possible_target.current) && (possible_target.current.stat != 2) && (!possible_target.special_role))
			possible_targets += possible_target
			for(var/role in roles)
				if(possible_target.assigned_role == role)
					priority_targets += possible_target
					continue

	if(priority_targets.len > 0)
		target = pick(priority_targets)
	else if(possible_targets.len > 0)
		target = pick(possible_targets)

	if(target && target.current)
		explanation_text = "We can get a good price for [target.current.real_name], the [target.assigned_role]. Take them alive."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/heist/kidnap/check_completion()
	if(target && target.current)
		if (target.current.stat == 2)
			return 0 // They're dead. Fail.
		//if (!target.current.restrained())
		//	return 0 // They're loose. Close but no cigar.

		var/area/skipjack_station/start/A = locate()
		for(var/mob/living/carbon/human/M in A)
			if(target.current == M)
				return 1 //They're restrained on the shuttle. Success.
	else
		return 0

/datum/objective/heist/loot

/datum/objective/heist/loot/choose_target()
	var/loot = "an object"
	switch(rand(1,8))
		if(1)
			target = /obj/structure/particle_accelerator
			target_amount = 6
			loot = "a complete particle accelerator"
		if(2)
			target = /obj/machinery/the_singularitygen
			target_amount = 1
			loot = "a gravitational generator"
		if(3)
			target = /obj/machinery/power/emitter
			target_amount = 4
			loot = "four emitters"
		if(4)
			target = /obj/machinery/nuclearbomb
			target_amount = 1
			loot = "a nuclear bomb"
		if(5)
			target = /obj/item/weapon/gun
			target_amount = 6
			loot = "six guns"
		if(6)
			target = /obj/item/weapon/gun/energy
			target_amount = 4
			loot = "four energy guns"
		if(7)
			target = /obj/item/weapon/gun/energy/laser
			target_amount = 2
			loot = "two laser guns"
		if(8)
			target = /obj/item/weapon/gun/energy/ionrifle
			target_amount = 1
			loot = "an ion gun"

	explanation_text = "It's a buyer's market out here. Steal [loot] for resale."

/datum/objective/heist/loot/check_completion()

	var/total_amount = 0

	for(var/obj/O in locate(/area/skipjack_station/start))
		if(istype(O,target)) total_amount++
		for(var/obj/I in O.contents)
			if(istype(I,target)) total_amount++
		if(total_amount >= target_amount) return 1

	for(var/datum/mind/raider in GLOB.raiders.current_antagonists)
		if(raider.current)
			for(var/obj/O in raider.current.get_contents())
				if(istype(O,target)) total_amount++
				if(total_amount >= target_amount) return 1

	return 0

/datum/objective/heist/salvage

/datum/objective/heist/salvage/choose_target()
	switch(rand(1,8))
		if(1)
			target = DEFAULT_WALL_MATERIAL
			target_amount = 300
		if(2)
			target = "glass"
			target_amount = 200
		if(3)
			target = "plasteel"
			target_amount = 100
		if(4)
			target = "phoron"
			target_amount = 100
		if(5)
			target = "silver"
			target_amount = 50
		if(6)
			target = "gold"
			target_amount = 20
		if(7)
			target = "uranium"
			target_amount = 20
		if(8)
			target = "diamond"
			target_amount = 20

	explanation_text = "Ransack the [station_name()] and escape with [target_amount] [target]."

/datum/objective/heist/salvage/check_completion()
	var/total_amount = 0

	for(var/obj/item/O in locate(/area/skipjack_station/start))
		var/obj/item/stack/material/S
		if(istype(O,/obj/item/stack/material))
			if(O.name == target)
				S = O
				total_amount += S.get_amount()
		for(var/obj/I in O.contents)
			if(istype(I,/obj/item/stack/material))
				if(I.name == target)
					S = I
					total_amount += S.get_amount()

	for(var/datum/mind/raider in GLOB.raiders.current_antagonists)
		if(raider.current)
			for(var/obj/item/O in raider.current.get_contents())
				if(istype(O,/obj/item/stack/material))
					if(O.name == target)
						var/obj/item/stack/material/S = O
						total_amount += S.get_amount()

	if(total_amount >= target_amount) return 1
	return 0


/datum/objective/heist/preserve_crew
	explanation_text = "Do not leave anyone behind, alive or dead."

/datum/objective/heist/preserve_crew/check_completion()
		if(GLOB.raiders && GLOB.raiders.is_raider_crew_safe()) return 1
		return 0

/datum/objective/ninja_highlander
	explanation_text = "You aspire to be a Grand Master of the Spider Clan. Kill all of your fellow acolytes."

/datum/objective/ninja_highlander/check_completion()
	if(owner)
		for(var/datum/mind/ninja in get_antags("ninja"))
			if(ninja != owner)
				if(ninja.current.stat < 2) return 0
		return 1
	return 0

/datum/objective/rev/find_target()
	..()
	if(target && target.current)
		explanation_text = "Assassinate, capture or convert [target.current.real_name], the [target.assigned_role]."
	else
		explanation_text = "Free Objective"
	return target


/datum/objective/rev/find_target_by_role(role, role_type=0)
	..(role, role_type)
	if(target && target.current)
		explanation_text = "Assassinate, capture or convert [target.current.real_name], the [!role_type ? target.assigned_role : target.special_role]."
	else
		explanation_text = "Free Objective"
	return target

/datum/objective/rev/check_completion()
	var/rval = 1
	if(target && target.current)
		var/mob/living/carbon/human/H = target.current
		if(!istype(H))
			return 1
		if(H.stat == DEAD || H.restrained())
			return 1
		// Check if they're converted
		if(target in GLOB.revs.current_antagonists)
			return 1
		var/turf/T = get_turf(H)
		if(T && isNotStationLevel(T.z))			//If they leave the station they count as dead for this
			rval = 2
		return 0
	return rval

/datum/objective/money
	var/value = 5000

/datum/objective/money/New()
	value = round(rand(5000,25000),100)
	explanation_text = "Acquire [value] thalers by the end of the shift through any means possible."

/datum/objective/money/check_completion()
	var/list/all_items = owner.current.get_contents()
	var/total_worth = 0
	for(var/obj/item/weapon/spacecash/sc in all_items)
		total_worth += sc.worth
	if(total_worth >= value)
		return TRUE
	return FALSE
