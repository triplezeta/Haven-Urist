/*
	Global associative list for caching humanoid icons.
	Index format m or f, followed by a string of 0 and 1 to represent bodyparts followed by husk fat hulk skeleton 1 or 0.
	TODO: Proper documentation
	icon_key is [species.race_key][g][husk][fat][hulk][skeleton][s_tone]
*/
var/global/list/human_icon_cache = list()
var/global/list/tail_icon_cache = list() //key is [species.race_key][r_skin][g_skin][b_skin]
var/global/list/light_overlay_cache = list()

/proc/overlay_image(icon,icon_state,color,flags)
	var/image/ret = image(icon,icon_state)
	ret.color = color
	ret.appearance_flags = flags
	return ret

	///////////////////////
	//UPDATE_ICONS SYSTEM//
	///////////////////////
/*
Calling this  a system is perhaps a bit trumped up. It is essentially update_clothing dismantled into its
core parts. The key difference is that when we generate overlays we do not generate either lying or standing
versions. Instead, we generate both and store them in two fixed-length lists, both using the same list-index
(The indexes are in update_icons.dm): Each list for humans is (at the time of writing) of length 19.
This will hopefully be reduced as the system is refined.

	var/overlays_lying[19]			//For the lying down stance
	var/overlays_standing[19]		//For the standing stance

When we call update_icons, the 'lying' variable is checked and then the appropriate list is assigned to our overlays!
That in itself uses a tiny bit more memory (no more than all the ridiculous lists the game has already mind you).

On the other-hand, it should be very CPU cheap in comparison to the old system.
In the old system, we updated all our overlays every life() call, even if we were standing still inside a crate!
or dead!. 25ish overlays, all generated from scratch every second for every xeno/human/monkey and then applied.
More often than not update_clothing was being called a few times in addition to that! CPU was not the only issue,
all those icons had to be sent to every client. So really the cost was extremely cumulative. To the point where
update_clothing would frequently appear in the top 10 most CPU intensive procs during profiling.

Another feature of this new system is that our lists are indexed. This means we can update specific overlays!
So we only regenerate icons when we need them to be updated! This is the main saving for this system.

In practice this means that:
	everytime you fall over, we just switch between precompiled lists. Which is fast and cheap.
	Everytime you do something minor like take a pen out of your pocket, we only update the in-hand overlay
	etc...


There are several things that need to be remembered:

>	Whenever we do something that should cause an overlay to update (which doesn't use standard procs
	( i.e. you do something like l_hand = /obj/item/something new(src) )
	You will need to call the relevant update_inv_* proc:
		update_inv_head()
		update_inv_wear_suit()
		update_inv_gloves()
		update_inv_shoes()
		update_inv_w_uniform()
		update_inv_glasse()
		update_inv_l_hand()
		update_inv_r_hand()
		update_inv_belt()
		update_inv_wear_id()
		update_inv_ears()
		update_inv_s_store()
		update_inv_pockets()
		update_inv_back()
		update_inv_handcuffed()
		update_inv_wear_mask()

	All of these are named after the variable they update from. They are defined at the mob/ level like
	update_clothing was, so you won't cause undefined proc runtimes with usr.update_inv_wear_id() if the usr is a
	slime etc. Instead, it'll just return without doing any work. So no harm in calling it for slimes and such.


>	There are also these special cases:
		update_mutations()	//handles updating your appearance for certain mutations.  e.g TK head-glows
		UpdateDamageIcon()	//handles damage overlays for brute/burn damage //(will rename this when I geta round to it)
		update_body()	//Handles updating your mob's icon to reflect their gender/race/complexion etc
		update_hair()	//Handles updating your hair overlay (used to be update_face, but mouth and
																			...eyes were merged into update_body)
		update_targeted() // Updates the target overlay when someone points a gun at you

>	All of these procs update our overlays_lying and overlays_standing, and then call update_icons() by default.
	If you wish to update several overlays at once, you can set the argument to 0 to disable the update and call
	it manually:
		e.g.
		update_inv_head(0)
		update_inv_l_hand(0)
		update_inv_r_hand()		//<---calls update_icons()

	or equivillantly:
		update_inv_head(0)
		update_inv_l_hand(0)
		update_inv_r_hand(0)
		update_icons()

>	If you need to update all overlays you can use regenerate_icons(). it works exactly like update_clothing used to.

>	I reimplimented an old unused variable which was in the code called (coincidentally) var/update_icon
	It can be used as another method of triggering regenerate_icons(). It's basically a flag that when set to non-zero
	will call regenerate_icons() at the next life() call and then reset itself to 0.
	The idea behind it is icons are regenerated only once, even if multiple events requested it.

This system is confusing and is still a WIP. It's primary goal is speeding up the controls of the game whilst
reducing processing costs. So please bear with me while I iron out the kinks. It will be worth it, I promise.
If I can eventually free var/lying stuff from the life() process altogether, stuns/death/status stuff
will become less affected by lag-spikes and will be instantaneous! :3

If you have any questions/constructive-comments/bugs-to-report/or have a massivly devestated butt...
Please contact me on #coderbus IRC. ~Carn x
*/

//Human Overlays Indexes/////////
#define HUMAN_OVERLAYS_MUTATIONS_INDEX           1
#define HUMAN_OVERLAYS_SKIN_INDEX                2
#define HUMAN_OVERLAYS_DAMAGE_INDEX              3
#define HUMAN_OVERLAYS_SURGERY_INDEX             4      //bs12 specific.
#define HUMAN_OVERLAYS_UNDERWEAR_INDEX           5
#define HUMAN_OVERLAYS_UNIFORM_INDEX             6
#define HUMAN_OVERLAYS_ID_INDEX                  7
#define HUMAN_OVERLAYS_SHOES_INDEX               8
#define HUMAN_OVERLAYS_GLOVES_INDEX              9
#define HUMAN_OVERLAYS_BELT_INDEX               10
#define HUMAN_OVERLAYS_SUIT_INDEX               11
#define HUMAN_OVERLAYS_TAIL_INDEX               12      //bs12 specific. this hack is probably gonna come back to haunt me
#define HUMAN_OVERLAYS_GLASSES_INDEX            13
#define HUMAN_OVERLAYS_BELT_ALT_INDEX           14
#define HUMAN_OVERLAYS_SUIT_STORE_INDEX         15
#define HUMAN_OVERLAYS_BACK_INDEX               16
#define HUMAN_OVERLAYS_HAIR_INDEX               17      //TODO: make part of head layer?
#define HUMAN_OVERLAYS_GOGGLES_INDEX            18
#define HUMAN_OVERLAYS_EARS_INDEX               19
#define HUMAN_OVERLAYS_FACEMASK_INDEX           20
#define HUMAN_OVERLAYS_HEAD_INDEX               21
#define HUMAN_OVERLAYS_COLLAR_INDEX             22
#define HUMAN_OVERLAYS_HANDCUFF_INDEX           23
#define HUMAN_OVERLAYS_L_HAND_INDEX             24
#define HUMAN_OVERLAYS_R_HAND_INDEX             25
#define HUMAN_OVERLAYS_FIRE_INDEX               26      //If you're on fire
#define HUMAN_OVERLAYS_TARGETED_INDEX           27      //BS12: Layer for the target overlay from weapon targeting system

#define HUMAN_OVERLAYS_SIZE                     27
//////////////////////////////////

/mob/living/carbon/human
	var/list/overlays_standing[HUMAN_OVERLAYS_SIZE]
	var/previous_damage_appearance // store what the body last looked like, so we only have to update it if something changed

//UPDATES OVERLAYS FROM OVERLAYS_LYING/OVERLAYS_STANDING
/mob/living/carbon/human/update_icons()
	lying_prev = lying	//so we don't update overlays for lying/standing unless our stance changes again
	update_hud()		//TODO: remove the need for this
	cut_overlays()

	var/list/overlays_to_apply = list()
	if (icon_update)

		var/list/visible_overlays
		if(is_cloaked())
			icon = 'icons/mob/human.dmi'
			icon_state = "blank"
			visible_overlays = list(visible_overlays[HUMAN_OVERLAYS_R_HAND_INDEX], visible_overlays[HUMAN_OVERLAYS_L_HAND_INDEX])
		else
			icon = stand_icon
			icon_state = null
			visible_overlays = (overlays_standing + get_emissive_blocker())

		var/matrix/M = matrix()
		if(lying && (species.prone_overlay_offset[1] || species.prone_overlay_offset[2]))
			M.Translate(species.prone_overlay_offset[1], species.prone_overlay_offset[2])

		for(var/i = 1 to LAZY_LENGTH(visible_overlays))
			var/entry = visible_overlays[i]
			if(istype(entry, /image))
				var/image/overlay = entry
				if(i != HUMAN_OVERLAYS_DAMAGE_INDEX)
					overlay.transform = M
				overlays_to_apply += overlay
			else if(istype(entry, /atom/movable/emissive_blocker))
				var/atom/movable/emissive_blocker/blocker = entry
				var/image/I = image(blocker)
				I.plane = get_float_plane(EMISSIVE_PLANE)
				overlays_to_apply += I
			else if(istype(entry, /list))
				for(var/image/overlay in entry)
					if(i != HUMAN_OVERLAYS_DAMAGE_INDEX)
						overlay.transform = M
					overlays_to_apply += overlay

		var/obj/item/organ/external/head/head = organs_by_name[BP_HEAD]
		if(istype(head) && !head.is_stump())
			var/image/I = head.get_eye_overlay()
			if(I) overlays_to_apply += I

	if(auras)
		overlays_to_apply += auras

	add_overlay(overlays_to_apply)

	var/matrix/M = matrix()
	if(lying)
		M.Turn(90)
		M.Scale(size_multiplier)
		M.Translate(1,-6)
	else
		M.Scale(size_multiplier)
		M.Translate(0, 16*(size_multiplier-1))
	transform = M

var/global/list/damage_icon_parts = list()

//DAMAGE OVERLAYS
//constructs damage icon for each organ from mask * damage field and saves it in our overlays_ lists
/mob/living/carbon/human/UpdateDamageIcon(var/update_icons=1)
	// first check whether something actually changed about damage appearance
	var/damage_appearance = ""

	if(!species.damage_overlays || !species.damage_mask)
		return

	for(var/obj/item/organ/external/O in organs)
		if(O.is_stump())
			continue
		damage_appearance += O.damage_state

	if(damage_appearance == previous_damage_appearance)
		// nothing to do here
		return

	previous_damage_appearance = damage_appearance

	var/image/standing_image = image(species.damage_overlays, icon_state = "00")

	// blend the individual damage states with our icons
	for(var/obj/item/organ/external/O in organs)
		if(O.is_stump())
			continue

		O.update_damstate()
		O.update_icon()
		if(O.damage_state == "00") continue
		var/icon/DI
		var/use_colour = (BP_IS_ROBOTIC(O) ? SYNTH_BLOOD_COLOUR : O.species.get_blood_colour(src))
		var/cache_index = "[O.damage_state]/[O.icon_name]/[use_colour]/[species.get_bodytype(src)]"
		if(damage_icon_parts[cache_index] == null)
			DI = new /icon(species.get_damage_overlays(src), O.damage_state)			// the damage icon for whole human
			DI.Blend(new /icon(species.get_damage_mask(src), O.icon_name), ICON_MULTIPLY)	// mask with this organ's pixels
			DI.Blend(use_colour, ICON_MULTIPLY)
			damage_icon_parts[cache_index] = DI
		else
			DI = damage_icon_parts[cache_index]

		standing_image.overlays += DI

	overlays_standing[HUMAN_OVERLAYS_DAMAGE_INDEX]	= standing_image

	if(update_icons)
		queue_icon_update()

//BASE MOB SPRITE
/mob/living/carbon/human/proc/update_body(var/update_icons=1)
	var/husk_color_mod = rgb(96,88,80)
	var/hulk_color_mod = rgb(48,224,40)

	var/husk = (HUSK in src.mutations)
	var/fat = (FAT in src.mutations)
	var/hulk = (HULK in src.mutations)
	var/skeleton = (SKELETON in src.mutations)

	//CACHING: Generate an index key from visible bodyparts.
	//0 = destroyed, 1 = normal, 2 = robotic, 3 = necrotic.

	//Create a new, blank icon for our mob to use.
	if(stand_icon)
		qdel(stand_icon)
	stand_icon = new(species.icon_template || 'icons/mob/human.dmi',"blank")

	var/g = "male"
	if(gender == FEMALE)
		g = "female"

	var/icon_key = "[species.get_race_key(src)][g][s_tone][r_skin][g_skin][b_skin]"
	if(lip_style)
		icon_key += "[lip_style]"
	else
		icon_key += "nolips"
	var/obj/item/organ/internal/eyes/eyes = internal_organs_by_name[species.vision_organ || BP_EYES]
	if(istype(eyes))
		icon_key += "[rgb(eyes.eye_colour[1], eyes.eye_colour[2], eyes.eye_colour[3])]"
	else
		icon_key += "#000000"

	for(var/organ_tag in species.has_limbs)
		var/obj/item/organ/external/part = organs_by_name[organ_tag]
		if(isnull(part) || part.is_stump())
			icon_key += "0"
			continue
		for(var/M in part.markings)
			icon_key += "[M][part.markings[M]["color"]]"
		if(part)
			icon_key += "[part.species.get_race_key(part.owner)]"
			icon_key += "[part.dna.GetUIState(DNA_UI_GENDER)]"
			icon_key += "[part.s_tone]"
			icon_key += "[part.s_base]"
			if(part.s_col && part.s_col.len >= 3)
				icon_key += "[rgb(part.s_col[1],part.s_col[2],part.s_col[3])]"
				icon_key += "[part.s_col_blend]"
			if(part.body_hair && part.h_col && part.h_col.len >= 3)
				icon_key += "[rgb(part.h_col[1],part.h_col[2],part.h_col[3])]"
			else
				icon_key += "#000000"
			for(var/M in part.markings)
				icon_key += "[M][part.markings[M]["color"]]"
		if(BP_IS_ROBOTIC(part))
			icon_key += "2[part.model ? "-[part.model]": ""]"
		else if(part.status & ORGAN_DEAD)
			icon_key += "3"
		else
			icon_key += "1"

	icon_key = "[icon_key][husk ? 1 : 0][fat ? 1 : 0][hulk ? 1 : 0][skeleton ? 1 : 0]"

	var/icon/base_icon
	if(human_icon_cache[icon_key])
		base_icon = human_icon_cache[icon_key]
	else
		//BEGIN CACHED ICON GENERATION.
		var/obj/item/organ/external/chest = get_organ(BP_CHEST)
		base_icon = chest.get_icon()

		for(var/obj/item/organ/external/part in (organs-chest))
			var/icon/temp = part.get_icon()
			//That part makes left and right legs drawn topmost and lowermost when human looks WEST or EAST
			//And no change in rendering for other parts (they icon_position is 0, so goes to 'else' part)
			if(part.icon_position & (LEFT | RIGHT))
				var/icon/temp2 = new('icons/mob/human.dmi',"blank")
				temp2.Insert(new/icon(temp,dir=NORTH),dir=NORTH)
				temp2.Insert(new/icon(temp,dir=SOUTH),dir=SOUTH)
				if(!(part.icon_position & LEFT))
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)
				if(!(part.icon_position & RIGHT))
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)
				base_icon.Blend(temp2, ICON_OVERLAY)
				if(part.icon_position & LEFT)
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)
				if(part.icon_position & RIGHT)
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)
				base_icon.Blend(temp2, ICON_UNDERLAY)
			else if(part.icon_position & UNDER)
				base_icon.Blend(temp, ICON_UNDERLAY)
			else
				base_icon.Blend(temp, ICON_OVERLAY)

		if(!skeleton)
			if(husk)
				base_icon.ColorTone(husk_color_mod)
			else if(hulk)
				var/list/tone = ReadRGB(hulk_color_mod)
				base_icon.MapColors(rgb(tone[1],0,0),rgb(0,tone[2],0),rgb(0,0,tone[3]))

		//Handle husk overlay.
		if(husk)
			var/husk_icon = species.get_husk_icon(src)
			if(husk_icon)
				var/icon/mask = new(base_icon)
				var/icon/husk_over = new(species.husk_icon,"")
				mask.MapColors(0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,0)
				husk_over.Blend(mask, ICON_ADD)
				base_icon.Blend(husk_over, ICON_OVERLAY)

		human_icon_cache[icon_key] = base_icon

	//END CACHED ICON GENERATION.
	stand_icon.Blend(base_icon,ICON_OVERLAY)

	//tail
	update_tail_showing(0)

	if(update_icons)
		queue_icon_update()

//UNDERWEAR OVERLAY

/mob/living/carbon/human/proc/update_underwear(var/update_icons=1)
	overlays_standing[HUMAN_OVERLAYS_UNDERWEAR_INDEX] = list()
	for(var/entry in worn_underwear)
		var/obj/item/underwear/UW = entry

		var/image/I = image(icon = UW.icon, icon_state = UW.icon_state)
		I.appearance_flags = RESET_COLOR
		I.color = UW.color

		overlays_standing[HUMAN_OVERLAYS_UNDERWEAR_INDEX] += I

	if(update_icons)
		queue_icon_update()

//HAIR OVERLAY
/mob/living/carbon/human/proc/update_hair(var/update_icons=1)
	//Reset our hair
	overlays_standing[HUMAN_OVERLAYS_HAIR_INDEX]	= null

	var/obj/item/organ/external/head/head_organ = get_organ(BP_HEAD)
	if(!head_organ || head_organ.is_stump() )
		if(update_icons)
			queue_icon_update()
		return

	//masks and helmets can obscure our hair.
	if( (head && (head.flags_inv & BLOCKHAIR)) || (wear_mask && (wear_mask.flags_inv & BLOCKHAIR)))
		if(update_icons)
			queue_icon_update()
		return

	overlays_standing[HUMAN_OVERLAYS_HAIR_INDEX]	= head_organ.get_hair_icon()

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/update_skin(var/update_icons=1)
	overlays_standing[HUMAN_OVERLAYS_SKIN_INDEX] = species.update_skin(src)
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_mutations(var/update_icons=1)
	var/fat
	if(FAT in mutations)
		fat = "fat"

	var/image/standing	= overlay_image('icons/effects/genetics.dmi', flags=RESET_COLOR)
	var/add_image = 0
	var/g = "m"
	if(gender == FEMALE)	g = "f"
	// DNA2 - Drawing underlays.
	for(var/datum/dna/gene/gene in dna_genes)
		if(!gene.block)
			continue
		if(gene.is_active(src))
			var/underlay=gene.OnDrawUnderlays(src,g,fat)
			if(underlay)
				standing.underlays += underlay
				add_image = 1
	for(var/mut in mutations)
		switch(mut)
			if(MUTATION_LASER)
				standing.overlays	+= "lasereyes_s"
				add_image = 1
	if(add_image)
		overlays_standing[HUMAN_OVERLAYS_MUTATIONS_INDEX]	= standing
	else
		overlays_standing[HUMAN_OVERLAYS_MUTATIONS_INDEX]	= null
	if(update_icons)
		queue_icon_update()
/* --------------------------------------- */
//For legacy support.
/mob/living/carbon/human/regenerate_icons()
	..()
	if(HasMovementHandler(/datum/movement_handler/mob/transformation) || QDELETED(src))		return

	update_mutations(0)
	update_body(0)
	update_skin(0)
	update_underwear(0)
	update_hair(0)
	update_inv_w_uniform(0)
	update_inv_wear_id(0)
	update_inv_gloves(0)
	update_inv_glasses(0)
	update_inv_ears(0)
	update_inv_shoes(0)
	update_inv_s_store(0)
	update_inv_wear_mask(0)
	update_inv_head(0)
	update_inv_belt(0)
	update_inv_back(0)
	update_inv_wear_suit(0)
	update_inv_r_hand(0)
	update_inv_l_hand(0)
	update_inv_handcuffed(0)
	update_inv_pockets(0)
	update_fire(0)
	update_surgery(0)
	UpdateDamageIcon()
	queue_icon_update()
	//Hud Stuff
	update_hud()

/* --------------------------------------- */
//vvvvvv UPDATE_INV PROCS vvvvvv

/mob/living/carbon/human/update_inv_w_uniform(var/update_icons=1)
	if(istype(w_uniform, /obj/item/clothing/under) && !(wear_suit && wear_suit.flags_inv & HIDEJUMPSUIT))
		overlays_standing[HUMAN_OVERLAYS_UNIFORM_INDEX]	= w_uniform.get_mob_overlay(src,slot_w_uniform_str)
	else
		overlays_standing[HUMAN_OVERLAYS_UNIFORM_INDEX]	= null

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_wear_id(var/update_icons=1)
	var/image/id_overlay
	if(wear_id && istype(w_uniform, /obj/item/clothing/under))
		var/obj/item/clothing/under/U = w_uniform
		if(U.displays_id && !U.rolled_down)
			id_overlay = wear_id.get_mob_overlay(src,slot_wear_id_str)

	overlays_standing[HUMAN_OVERLAYS_ID_INDEX]	= id_overlay

	BITSET(hud_updateflag, ID_HUD)
	BITSET(hud_updateflag, WANTED_HUD)

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_gloves(var/update_icons=1)
	if(gloves && !(wear_suit && wear_suit.flags_inv & HIDEGLOVES))
		overlays_standing[HUMAN_OVERLAYS_GLOVES_INDEX]	= gloves.get_mob_overlay(src,slot_gloves_str)
	else
		if(blood_DNA && species.blood_mask)
			var/image/bloodsies	= overlay_image(species.blood_mask, "bloodyhands", hand_blood_color, RESET_COLOR)
			overlays_standing[HUMAN_OVERLAYS_GLOVES_INDEX]	= bloodsies
		else
			overlays_standing[HUMAN_OVERLAYS_GLOVES_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_glasses(var/update_icons=1)
	if(glasses)
		overlays_standing[glasses.use_alt_layer ? HUMAN_OVERLAYS_GOGGLES_INDEX : HUMAN_OVERLAYS_GLASSES_INDEX] = glasses.get_mob_overlay(src,slot_glasses_str)
		overlays_standing[glasses.use_alt_layer ? HUMAN_OVERLAYS_GLASSES_INDEX : HUMAN_OVERLAYS_GOGGLES_INDEX] = null
	else
		overlays_standing[HUMAN_OVERLAYS_GLASSES_INDEX]	= null
		overlays_standing[HUMAN_OVERLAYS_GOGGLES_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_ears(var/update_icons=1)
	overlays_standing[HUMAN_OVERLAYS_EARS_INDEX] = null
	if( (head && (head.flags_inv & (BLOCKHAIR | BLOCKHEADHAIR))) || (wear_mask && (wear_mask.flags_inv & (BLOCKHAIR | BLOCKHEADHAIR))))
		if(update_icons)
			queue_icon_update()
		return

	if(l_ear || r_ear)
		// Blank image upon which to layer left & right overlays.
		var/image/both = image("icon" = 'icons/effects/effects.dmi', "icon_state" = "nothing")
		if(l_ear)
			both.overlays += l_ear.get_mob_overlay(src,slot_l_ear_str)
		if(r_ear)
			both.overlays += r_ear.get_mob_overlay(src,slot_r_ear_str)
		overlays_standing[HUMAN_OVERLAYS_EARS_INDEX] = both

	else
		overlays_standing[HUMAN_OVERLAYS_EARS_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_shoes(var/update_icons=1)
	if(shoes && !((wear_suit && wear_suit.flags_inv & HIDESHOES) || (w_uniform && w_uniform.flags_inv & HIDESHOES)))
		overlays_standing[HUMAN_OVERLAYS_SHOES_INDEX] = shoes.get_mob_overlay(src,slot_shoes_str)
	else
		if(feet_blood_DNA && species.blood_mask)
			var/image/bloodsies = overlay_image(species.blood_mask, "shoeblood", hand_blood_color, RESET_COLOR)
			overlays_standing[HUMAN_OVERLAYS_SHOES_INDEX] = bloodsies
		else
			overlays_standing[HUMAN_OVERLAYS_SHOES_INDEX] = null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_s_store(var/update_icons=1)
	if(s_store)
		overlays_standing[HUMAN_OVERLAYS_SUIT_STORE_INDEX]	= s_store.get_mob_overlay(src,slot_s_store_str)
	else
		overlays_standing[HUMAN_OVERLAYS_SUIT_STORE_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_head(var/update_icons=1)
	if(head)
		overlays_standing[HUMAN_OVERLAYS_HEAD_INDEX] = head.get_mob_overlay(src,slot_head_str)
	else
		overlays_standing[HUMAN_OVERLAYS_HEAD_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_belt(var/update_icons=1)
	if(belt)
		overlays_standing[belt.use_alt_layer ? HUMAN_OVERLAYS_BELT_ALT_INDEX : HUMAN_OVERLAYS_BELT_INDEX] = belt.get_mob_overlay(src,slot_belt_str)
		overlays_standing[belt.use_alt_layer ? HUMAN_OVERLAYS_BELT_INDEX : HUMAN_OVERLAYS_BELT_ALT_INDEX] = null
	else
		overlays_standing[HUMAN_OVERLAYS_BELT_INDEX] = null
		overlays_standing[HUMAN_OVERLAYS_BELT_ALT_INDEX] = null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_wear_suit(var/update_icons=1)

	if(wear_suit)
		overlays_standing[HUMAN_OVERLAYS_SUIT_INDEX]	= wear_suit.get_mob_overlay(src,slot_wear_suit_str)
		update_tail_showing(0)
	else
		overlays_standing[HUMAN_OVERLAYS_SUIT_INDEX]	= null
		update_tail_showing(0)
		update_inv_w_uniform(0)
		update_inv_shoes(0)
		update_inv_gloves(0)

	update_collar(0)

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_pockets(var/update_icons=1)
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_wear_mask(var/update_icons=1)
	if( wear_mask && ( istype(wear_mask, /obj/item/clothing/mask) || istype(wear_mask, /obj/item/clothing/accessory) ) && !(head && head.flags_inv & HIDEMASK))
		overlays_standing[HUMAN_OVERLAYS_FACEMASK_INDEX]	= wear_mask.get_mob_overlay(src,slot_wear_mask_str)
	else
		overlays_standing[HUMAN_OVERLAYS_FACEMASK_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_back(var/update_icons=1)
	if(back)
		overlays_standing[HUMAN_OVERLAYS_BACK_INDEX] = back.get_mob_overlay(src,slot_back_str)
	else
		overlays_standing[HUMAN_OVERLAYS_BACK_INDEX] = null

	if(update_icons)
		queue_icon_update()


/mob/living/carbon/human/update_hud()	//TODO: do away with this if possible
	if(client)
		client.screen |= contents
		if(hud_used)
			hud_used.hidden_inventory_update() 	//Updates the screenloc of the items on the 'other' inventory bar

/mob/living/carbon/human/update_inv_handcuffed(var/update_icons=1)
	if(handcuffed)
		overlays_standing[HUMAN_OVERLAYS_HANDCUFF_INDEX] = handcuffed.get_mob_overlay(src,slot_handcuffed_str)
	else
		overlays_standing[HUMAN_OVERLAYS_HANDCUFF_INDEX]	= null
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_r_hand(var/update_icons=1)
	if(r_hand)
		var/image/standing = r_hand.get_mob_overlay(src,slot_r_hand_str)
		if(standing)
			standing.appearance_flags |= RESET_ALPHA
		overlays_standing[HUMAN_OVERLAYS_R_HAND_INDEX] = standing

		if (handcuffed) drop_r_hand() //this should be moved out of icon code
	else
		overlays_standing[HUMAN_OVERLAYS_R_HAND_INDEX] = null

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/update_inv_l_hand(var/update_icons=1)
	if(l_hand)
		var/image/standing = l_hand.get_mob_overlay(src,slot_l_hand_str)
		if(standing)
			standing.appearance_flags |= RESET_ALPHA
		overlays_standing[HUMAN_OVERLAYS_L_HAND_INDEX] = standing

		if (handcuffed) drop_l_hand() //This probably should not be here
	else
		overlays_standing[HUMAN_OVERLAYS_L_HAND_INDEX] = null

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/update_tail_showing(var/update_icons=1)
	overlays_standing[HUMAN_OVERLAYS_TAIL_INDEX] = null

	var/species_tail = species.get_tail(src)

	if(species_tail && !(wear_suit && wear_suit.flags_inv & HIDETAIL))
		var/icon/tail_s = get_tail_icon()
		overlays_standing[HUMAN_OVERLAYS_TAIL_INDEX] = image(tail_s, icon_state = "[species_tail]_s")
		animate_tail_reset(0)

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/get_tail_icon()
	var/icon_key = "[species.get_race_key(src)][r_skin][g_skin][b_skin][r_hair][g_hair][b_hair]"
	var/icon/tail_icon = tail_icon_cache[icon_key]
	if(!tail_icon)
		//generate a new one
		var/species_tail_anim = species.get_tail_animation(src)
		if(!species_tail_anim) species_tail_anim = 'icons/effects/species.dmi'
		tail_icon = new/icon(species_tail_anim)
		tail_icon.Blend(rgb(r_skin, g_skin, b_skin), species.tail_blend)
		// The following will not work with animated tails.
		var/use_species_tail = species.get_tail_hair(src)
		if(use_species_tail)
			var/icon/hair_icon = icon('icons/effects/species.dmi', "[species.get_tail(src)]_[use_species_tail]")
			hair_icon.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)
			tail_icon.Blend(hair_icon, ICON_OVERLAY)
		tail_icon_cache[icon_key] = tail_icon

	return tail_icon


/mob/living/carbon/human/proc/set_tail_state(var/t_state)
	var/image/tail_overlay = overlays_standing[HUMAN_OVERLAYS_TAIL_INDEX]

	if(tail_overlay && species.get_tail_animation(src))
		tail_overlay.icon_state = t_state
		return tail_overlay
	return null

//Not really once, since BYOND can't do that.
//Update this if the ability to flick() images or make looping animation start at the first frame is ever added.
/mob/living/carbon/human/proc/animate_tail_once(var/update_icons=1)
	var/t_state = "[species.get_tail(src)]_once"

	var/image/tail_overlay = overlays_standing[HUMAN_OVERLAYS_TAIL_INDEX]
	if(tail_overlay && tail_overlay.icon_state == t_state)
		return //let the existing animation finish

	tail_overlay = set_tail_state(t_state)
	if(tail_overlay)
		spawn(20)
			//check that the animation hasn't changed in the meantime
			if(overlays_standing[HUMAN_OVERLAYS_TAIL_INDEX] == tail_overlay && tail_overlay.icon_state == t_state)
				animate_tail_stop()

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/animate_tail_start(var/update_icons=1)
	set_tail_state("[species.get_tail(src)]_slow[rand(0,9)]")

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/animate_tail_fast(var/update_icons=1)
	set_tail_state("[species.get_tail(src)]_loop[rand(0,9)]")

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/animate_tail_reset(var/update_icons=1)
	if(stat != DEAD)
		set_tail_state("[species.get_tail(src)]_idle[rand(0,9)]")
	else
		set_tail_state("[species.get_tail(src)]_static")

	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/animate_tail_stop(var/update_icons=1)
	set_tail_state("[species.get_tail(src)]_static")

	if(update_icons)
		queue_icon_update()


//Adds a collar overlay above the helmet layer if the suit has one
//	Suit needs an identically named sprite in icons/mob/collar.dmi
/mob/living/carbon/human/proc/update_collar(var/update_icons=1)
	if(istype(wear_suit,/obj/item/clothing/suit))
		var/obj/item/clothing/suit/S = wear_suit
		overlays_standing[HUMAN_OVERLAYS_COLLAR_INDEX]	= S.get_collar()
	else
		overlays_standing[HUMAN_OVERLAYS_COLLAR_INDEX]	= null

	if(update_icons)
		queue_icon_update()


/mob/living/carbon/human/update_fire(var/update_icons=1)
	overlays_standing[HUMAN_OVERLAYS_FIRE_INDEX] = null
	if(on_fire)
		var/image/standing = overlay_image('icons/mob/OnFire.dmi', "Standing", RESET_COLOR)
		overlays_standing[HUMAN_OVERLAYS_FIRE_INDEX] = standing
	if(update_icons)
		queue_icon_update()

/mob/living/carbon/human/proc/update_surgery(var/update_icons=1)
	overlays_standing[HUMAN_OVERLAYS_SURGERY_INDEX] = null
	var/image/total = new
	for(var/obj/item/organ/external/E in organs)
		if(!BP_IS_ROBOTIC(E) && E.how_open())
			var/image/I = image("icon"='icons/mob/surgery.dmi', "icon_state"="[E.icon_name][round(E.how_open())]", "layer"=-HUMAN_OVERLAYS_SURGERY_INDEX)
			total.overlays += I
	total.appearance_flags = RESET_COLOR
	overlays_standing[HUMAN_OVERLAYS_SURGERY_INDEX] = total
	if(update_icons)
		queue_icon_update()

//Human Overlays Indexes/////////
#undef HUMAN_OVERLAYS_MUTATIONS_INDEX
#undef HUMAN_OVERLAYS_DAMAGE_INDEX
#undef HUMAN_OVERLAYS_SURGERY_INDEX
#undef HUMAN_OVERLAYS_UNIFORM_INDEX
#undef HUMAN_OVERLAYS_ID_INDEX
#undef HUMAN_OVERLAYS_SHOES_INDEX
#undef HUMAN_OVERLAYS_GLOVES_INDEX
#undef HUMAN_OVERLAYS_EARS_INDEX
#undef HUMAN_OVERLAYS_SUIT_INDEX
#undef HUMAN_OVERLAYS_TAIL_INDEX
#undef HUMAN_OVERLAYS_GLASSES_INDEX
#undef HUMAN_OVERLAYS_FACEMASK_INDEX
#undef HUMAN_OVERLAYS_BELT_INDEX
#undef HUMAN_OVERLAYS_SUIT_STORE_INDEX
#undef HUMAN_OVERLAYS_BACK_INDEX
#undef HUMAN_OVERLAYS_HAIR_INDEX
#undef HUMAN_OVERLAYS_HEAD_INDEX
#undef HUMAN_OVERLAYS_COLLAR_INDEX
#undef HUMAN_OVERLAYS_HANDCUFF_INDEX
#undef HUMAN_OVERLAYS_L_HAND_INDEX
#undef HUMAN_OVERLAYS_R_HAND_INDEX
#undef HUMAN_OVERLAYS_TARGETED_INDEX
#undef HUMAN_OVERLAYS_FIRE_INDEX
#undef HUMAN_OVERLAYS_SIZE
