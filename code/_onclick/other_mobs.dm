// Generic damage proc (slimes and monkeys).
/atom/proc/attack_generic(mob/user as mob)
	return 0

/*
	Humans:
	Adds an exception for gloves, to allow special glove types like the ninja ones.

	Otherwise pretty standard.
*/
/mob/living/carbon/human/UnarmedAttack(var/atom/A, var/proximity)

	if(!..())
		return

	// Special glove functions:
	// If the gloves do anything, have them return 1 to stop
	// normal attack_hand() here.
	var/obj/item/clothing/gloves/G = gloves // not typecast specifically enough in defines
	if(istype(G) && G.Touch(A,1))
		return

	A.attack_hand(src)

/mob/living/carbon/human/RestrainedClickOn(var/atom/A)
	return

/mob/living/carbon/human/RangedAttack(var/atom/A)
	//Climbing up open spaces
	if((istype(A, /turf/simulated/floor) || istype(A, /turf/unsimulated/floor) || istype(A, /obj/structure/lattice) || istype(A, /obj/structure/catwalk)) && isturf(loc) && shadow && !is_physically_disabled()) //Climbing through openspace
		var/turf/T = get_turf(A)
		var/turf/above = shadow.loc
		if(T.Adjacent(shadow) && above.CanZPass(src, UP)) //Certain structures will block passage from below, others not

			var/area/location = get_area(loc)
			if(location.has_gravity && !can_overcome_gravity())
				return

			visible_message("<span class='notice'>[src] starts climbing onto \the [A]!</span>", "<span class='notice'>You start climbing onto \the [A]!</span>")
			shadow.visible_message("<span class='notice'>[shadow] starts climbing onto \the [A]!</span>")
			if(do_after(src, 50, A))
				visible_message("<span class='notice'>[src] climbs onto \the [A]!</span>", "<span class='notice'>You climb onto \the [A]!</span>")
				shadow.visible_message("<span class='notice'>[shadow] climbs onto \the [A]!</span>")
				src.Move(T)
			else
				visible_message("<span class='warning'>[src] gives up on trying to climb onto \the [A]!</span>", "<span class='warning'>You give up on trying to climb onto \the [A]!</span>")
				shadow.visible_message("<span class='warning'>[shadow] gives up on trying to climb onto \the [A]!</span>")
			return

	if(!gloves && !mutations.len) return
	var/obj/item/clothing/gloves/G = gloves
	if((MUTATION_LASER in mutations) && a_intent == I_HURT)
		LaserEyes(A) // moved into a proc below

	else if(istype(G) && G.Touch(A,0)) // for magic gloves
		return

	else if(TK in mutations)
		A.attack_tk(src)

/mob/living/RestrainedClickOn(var/atom/A)
	return

/*
	Aliens
*/

/mob/living/carbon/alien/RestrainedClickOn(var/atom/A)
	return

/mob/living/carbon/alien/UnarmedAttack(var/atom/A, var/proximity)

	if(!..())
		return 0

	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	A.attack_generic(src,rand(5,6),"bitten")

/*
	Slimes
	Nothing happening here
*/

/mob/living/carbon/slime/RestrainedClickOn(var/atom/A)
	return

/mob/living/carbon/slime/UnarmedAttack(var/atom/A, var/proximity)

	if(!..())
		return

	// Eating
	if(Victim)
		if (Victim == A)
			Feedstop()
		return

	//should have already been set if we are attacking a mob, but it doesn't hurt and will cover attacking non-mobs too
	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	var/mob/living/M = A
	if(!istype(M))
		A.attack_generic(src, (is_adult ? rand(20,40) : rand(5,25)), "glomped") // Basic attack.
	else
		var/power = max(0, min(10, (powerlevel + rand(0, 3))))

		switch(src.a_intent)
			if (I_HELP) // We just poke the other
				M.visible_message("<span class='notice'>[src] gently pokes [M]!</span>", "<span class='notice'>[src] gently pokes you!</span>")
			if (I_DISARM) // We stun the target, with the intention to feed
				var/stunprob = 1

				if (powerlevel > 0 && !istype(A, /mob/living/carbon/slime))
					switch(power * 10)
						if(0) stunprob *= 10
						if(1 to 2) stunprob *= 20
						if(3 to 4) stunprob *= 30
						if(5 to 6) stunprob *= 40
						if(7 to 8) stunprob *= 60
						if(9) 	   stunprob *= 70
						if(10) 	   stunprob *= 95

				if(prob(stunprob))
					var/shock_damage = max(0, powerlevel-3) * rand(6,10)
					M.electrocute_act(shock_damage, src, 1.0, ran_zone())
				else if(prob(40))
					M.visible_message("<span class='danger'>[src] has pounced at [M]!</span>", "<span class='danger'>[src] has pounced at you!</span>")
					M.Weaken(power)
				else
					M.visible_message("<span class='danger'>[src] has tried to pounce at [M]!</span>", "<span class='danger'>[src] has tried to pounce at you!</span>")
				M.updatehealth()
			if (I_GRAB) // We feed
				Wrap(M)
			if (I_HURT) // Attacking
				if(iscarbon(M) && prob(15))
					M.visible_message("<span class='danger'>[src] has pounced at [M]!</span>", "<span class='danger'>[src] has pounced at you!</span>")
					M.Weaken(power)
				else
					A.attack_generic(src, (is_adult ? rand(20,40) : rand(5,25)), "glomped")

/*
	New Players:
	Have no reason to click on anything at all.
*/
/mob/new_player/ClickOn()
	return

/*
	Animals
*/
/mob/living/simple_animal/UnarmedAttack(var/atom/A, var/proximity)
	var/extra_data = environment_smash
	if(!..())
		return
	if(istype(A,/mob/living))
		extra_data = damage_type
		if(melee_damage_upper == 0)
			custom_emote(1,"[friendly] [A]!")
			return
		if(ckey)
			admin_attack_log(src, A, "Has [attacktext] its victim.", "Has been [attacktext] by its attacker.", attacktext)
	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	var/damage = rand(melee_damage_lower, melee_damage_upper)
	if(A.attack_generic(src,damage,attacktext,extra_data) && loc && attack_sound)
		playsound(loc, attack_sound, 50, 1, 1)
