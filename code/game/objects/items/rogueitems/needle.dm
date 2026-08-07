#define SEW_HP_EXP_NORMALIZER 100
// How much EXP per sewing action per intelligence
// 0.6 EXP at 10 INT
#define SEW_EXP_PER_STEP 0.06
// How much EXP per 100 sew threshold fixed per intelligence
// 7.5 EXP at 10 INT for 100 sew treshold
#define SEW_EXP_FINISH 0.75
// How many uses of thread a single strand of fiber winds onto a needle
#define FIBER_THREAD_USES 5

/obj/item/needle
	name = "needle"
	icon_state = "needle"
	desc = "This sharp needle can sew wounds, mend clothing, and stab someone if you’re desperate."
	icon = 'icons/roguetown/items/misc.dmi'
	lefthand_file = 'icons/mob/inhands/misc/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/food_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	force = 0
	throwforce = 0
	resistance_flags = FLAMMABLE
	slot_flags = ITEM_SLOT_MOUTH
	max_integrity = 20
	anvilrepair = /datum/skill/craft/blacksmithing
	tool_behaviour = TOOL_SUTURE
	experimental_inhand = TRUE
	/// Amount of uses left
	var/stringamt = 20
	var/maxstring = 20
	/// If this needle is infinite
	var/infinite = FALSE
	/// If this needle can be used to repair items
	var/can_repair = TRUE
	grid_width = 32
	grid_height = 32
	var/repair_busy = FALSE
	//dropshrink = 0.75
	// we store the overlay to avoid needless icon updates.
	var/mutable_appearance/thread_overlay

/obj/item/needle/examine()
	. = ..()
	if(!infinite)
		if(stringamt > 0)
			. += span_bold("It has [stringamt] uses left.")
		else
			. += span_bold("It has no uses left.")
	else
		. += "Can be used indefinitely."

/obj/item/needle/get_mechanics_examine(mob/user)
	. = ..()
	. += span_info("Left-click someone - while targeting the desired limb - to begin stitching a wound. Stitching automatically stops once you've completely sealed the specific wound.")
	. += span_info("While stitching a wound, it will bleed far slower than usual. This effect can be further stacked by applying cloth, bandages, or pressure to the wounded limb.")
	. += span_info("If multiple stitchable wounds are present on the targeted limb, you'll be given the option to choose which specific wound is treated first.")
	. += span_info("Needles require fibers to stitch, which can be found by cutting grass or foraging through bushes.")
	. += span_info("To rethread an emptied needle, left-click it with a strand of fiber. A fiber bundle works too, and will keep feeding strands in one at a time until the needle is full.")

/obj/item/needle/Initialize()
	. = ..()
	thread_overlay = mutable_appearance(icon, "[icon_state]string")
	if(stringamt > 0)
		add_overlay(thread_overlay)

/obj/item/needle/use(used)
	if(infinite)
		return TRUE
	var/old_amt = stringamt
	stringamt = max(0, stringamt - used)
	if(old_amt > 0 && stringamt <= 0)
		cut_overlay(thread_overlay)

/obj/item/needle/attack(mob/living/M, mob/user)
	sew(M, user)

/// Is there any point in threading this needle? Complains to the user if not.
/obj/item/needle/proc/can_rethread(mob/user)
	if(infinite || maxstring - stringamt <= 0) //is the needle infinite OR does it have all of its uses left
		to_chat(user, span_warning("The needle has no need to be refilled."))
		return FALSE
	return TRUE

/obj/item/needle/proc/rethread_time(mob/user)
	return 6 SECONDS - user.get_skill_level(/datum/skill/craft/sewing)

/obj/item/needle/proc/rethread()
	var/old_amt = stringamt
	var/gained = min(FIBER_THREAD_USES, (maxstring - stringamt))
	stringamt += gained
	if(old_amt <= 0 && stringamt > 0)
		add_overlay(thread_overlay)
	return gained

/obj/item/needle/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/natural/bundle))
		var/obj/item/natural/bundle/B = I
		if(!ispath(B.stacktype, /obj/item/natural/fibers)) //only bundles of something we could thread by hand
			return ..()
		if(!can_rethread(user))
			return

		to_chat(user, "I begin threading the needle from [B]...")
		var/refill_amount = 0
		while((stringamt < maxstring) && !QDELETED(B) && (B.amount > 0)) //one strand at a time, until full or the bundle runs dry
			if(!do_after(user, rethread_time(user), target = B))
				break
			if(QDELETED(B) || !B.use(1)) //use() unwinds the bundle itself once it's down to a single strand
				break
			refill_amount += rethread()
		if(refill_amount)
			to_chat(user, "I replenish the needle's thread by [refill_amount] uses!")
		return

	if(istype(I, /obj/item/natural/fibers))
		if(!can_rethread(user))
			return

		to_chat(user, "I begin threading the needle with additional fibers...")
		if(do_after(user, rethread_time(user), target = I))
			to_chat(user, "I replenish the needle's thread by [rethread()] uses!")
			qdel(I)
		return
	return ..()

/obj/item/needle/attack_obj(obj/O, mob/living/user)
	if(!isitem(O))
		return

	var/obj/item/attacked_item = O

	if(!attacked_item.sewrepair || (attacked_item.obj_integrity >= attacked_item.max_integrity) || !isturf(attacked_item.loc))
		return

	if(!attacked_item.ontable())
		to_chat(user, span_warning("I should put this on a table first."))
		return

	if(repair_busy)
		return
	repair_busy = TRUE
	var/user_skill = user.get_skill_level(/datum/skill/craft/sewing)
	var/scaling_override = (HAS_TRAIT(user, TRAIT_SQUIRE_REPAIR) || HAS_TRAIT(user, TRAIT_SELF_SUSTENANCE))
	var/stage_count = min(user_skill, 4)
	var/repair_percent = 0.2

	var/repair_delay = 3 SECONDS - (user_skill * (1 SECONDS / 6))

	user.visible_message(span_notice("[user] is preparing to repair [attacked_item]..."), span_notice("I am preparing to repair [attacked_item], I should remain still."))
	if(!do_after(user, repair_delay, TRUE, same_direction = TRUE, allow_movement = FALSE))
		repair_busy = FALSE
		return

	if(stage_count < 3 && scaling_override)
		repair_percent = 0.34
	else
		switch(stage_count)
			if(REPAIR_STAGE_ONE)
				repair_percent = 0.25
			if(REPAIR_STAGE_TWO)
				repair_percent = 0.34
			if(REPAIR_STAGE_THREE, REPAIR_STAGE_FINAL)
				repair_percent = 1
			else
				repair_percent = 0.2

	// If our skill is Expert or above, we won't diminish our max integ.
	// Otherwise, we need to have at least 1 level of skill and get lucky.
	var/base_prob = ((user.STALUC - 10) * 10) + (stage_count * 10)
	if(istype(src, /obj/item/needle/thorn) && stage_count < REPAIR_STAGE_FINAL)
		base_prob -= 10

	base_prob = max(base_prob, 0)

	var/keep_max_integ = ((stage_count > 3) || (prob(base_prob) && stage_count > 0))
	if(istype(attacked_item, /obj/item/clothing))
		var/obj/item/clothing/C = attacked_item
		if(C.armor_class == ARMOR_CLASS_MEDIUM && HAS_TRAIT(user, TRAIT_MEDIUMARMOR))
			keep_max_integ = TRUE
		if(C.armor_class == ARMOR_CLASS_HEAVY && HAS_TRAIT(user, TRAIT_HEAVYARMOR))
			keep_max_integ = TRUE

	// We keep our integ if we're repairing on a cool table regardless of tools.
	if((locate(/obj/structure/table/wood/fancy) in attacked_item.loc) || (locate(/obj/structure/table/wood/folding) in attacked_item.loc))
		keep_max_integ = TRUE

	// Ditto, but the other way around.
	if(!keep_max_integ)
		if(istype(src, /obj/item/needle/pestra))
			keep_max_integ = TRUE

	var/root_time = 0.7 SECONDS * stage_count
	var/cycle_complete = TRUE
	user.Immobilize(root_time)
	if(stage_count)
		for(var/i in 1 to stage_count)
			if(i == 1)
				attacked_item.perform_repair_effect(user, i, REPAIR_TYPE_SEW)
			else
				if(do_after(user, 0.7 SECONDS, TRUE, progress = FALSE, same_direction = TRUE))
					attacked_item.perform_repair_effect(user, i, REPAIR_TYPE_SEW)
				else
					cycle_complete = FALSE
	else
		playsound(get_turf(attacked_item), 'sound/foley/sewflesh.ogg', 100, TRUE, -2)

	// We spawn the bling if we keep max integ, for the dopamine.
	if(keep_max_integ && stage_count < REPAIR_STAGE_FINAL)
		attacked_item.perform_repair_effect(user, REPAIR_STAGE_FINAL)

	if(repair_percent && cycle_complete)
		repair_percent *= attacked_item.max_integrity
		var/exp_gained = min(attacked_item.obj_integrity + repair_percent, attacked_item.max_integrity) - attacked_item.obj_integrity
		if(!keep_max_integ)
			max_integrity -= 5
		attacked_item.obj_integrity = min(attacked_item.obj_integrity + repair_percent, attacked_item.max_integrity)
		user.visible_message(span_info("[user] repairs [attacked_item]!"))

		if(attacked_item.body_parts_covered != attacked_item.body_parts_covered_dynamic)
			user.visible_message(span_info("[user] repairs [attacked_item]'s coverage!"))
			attacked_item.repair_coverage()

		if(attacked_item.obj_broken && attacked_item.obj_integrity == attacked_item.max_integrity)
			attacked_item.obj_fix()

		if(stage_count == REPAIR_STAGE_FINAL && !attacked_item.GetComponent(/datum/component/fit_clothing))
			attacked_item.max_integrity = initial(attacked_item.max_integrity)

		user.mind.add_sleep_experience(/datum/skill/craft/sewing, exp_gained/2) //We gain as much exp as we fix divided by 2
		use(1)

	repair_busy = FALSE
	return ..()

/obj/item/needle/proc/sew(mob/living/target, mob/living/user)
	if(!istype(user))
		return FALSE
	var/mob/living/doctor = user
	var/mob/living/patient = target
	if(stringamt < 1)
		to_chat(user, span_warning("The needle has no thread left!"))
		return
	var/list/sewable
	var/obj/item/bodypart/affecting
	var/is_simple_animal = !iscarbon(patient)
	if(iscarbon(patient))
		affecting = patient.get_bodypart(check_zone(doctor.zone_selected))
		if(!affecting)
			to_chat(doctor, span_warning("That limb is missing."))
			return FALSE
		sewable = affecting.get_sewable_wounds()
	else
		sewable = patient.get_sewable_wounds()
	if(!length(sewable))
		to_chat(doctor, span_warning("There aren't any wounds to be sewn."))
		return FALSE
	var/datum/wound/target_wound = sewable.len > 1 ? input(doctor, "Which wound?", "[src]") as null|anything in sewable : sewable[1]
	if(!target_wound)
		return FALSE

	var/moveup = 10
	var/medskill = doctor.get_skill_level(/datum/skill/misc/medicine)
	var/informed = FALSE
	moveup = (medskill+1) * 4
	if(medskill > SKILL_LEVEL_EXPERT)
		if(medskill == SKILL_LEVEL_MASTER)
			moveup = medskill * 6
		else if(medskill == SKILL_LEVEL_LEGENDARY)
			moveup = medskill * 7
	while(!QDELETED(target_wound) && !QDELETED(src) && \
		!QDELETED(user) && (target_wound.sew_progress < target_wound.sew_threshold) && \
		stringamt >= 1)
		var/sewing_start_delay = 2 SECONDS
		if(medskill > SKILL_LEVEL_EXPERT)
			if(medskill == SKILL_LEVEL_MASTER)
				sewing_start_delay = 1.5 SECONDS
			else if(medskill == SKILL_LEVEL_LEGENDARY)
				sewing_start_delay = 1 SECONDS
		if(!do_after(doctor, sewing_start_delay, target = patient))
			break
		playsound(loc, 'sound/foley/sewflesh.ogg', 100, TRUE, -2)
		target_wound.sew_progress = min(target_wound.sew_progress + moveup, target_wound.sew_threshold)
		var/bleedreduction = max((0.5 * medskill), 0.5)
		if(medskill > SKILL_LEVEL_EXPERT)
			if(medskill == SKILL_LEVEL_MASTER)
				bleedreduction = 3
			else if(medskill == SKILL_LEVEL_LEGENDARY)
				bleedreduction = 4
		target_wound.set_bleed_rate(max( (target_wound.bleed_rate - bleedreduction), 0))
		if(target_wound.bleed_rate == 0 && !informed)
			if(is_simple_animal)
				patient.visible_message(span_smallgreen("One last drop of blood trickles from the [(target_wound?.name)] on [patient] before it closes."), span_smallgreen("The throbbing warmth coming out of the [target_wound] soothes and stops. It no longer bleeds."))
			else
				patient.visible_message(span_smallgreen("One last drop of blood trickles from the [(target_wound?.name)] on [patient]'s [affecting.name] before it closes."), span_smallgreen("The throbbing warmth coming out of the [target_wound] soothes and stops. It no longer bleeds."))
			informed = TRUE
		if(istype(target_wound, /datum/wound/dynamic))
			var/datum/wound/dynamic/dynwound = target_wound
			if(dynwound.is_maxed)
				dynwound.is_maxed = FALSE
			if(dynwound.is_armor_maxed)
				dynwound.is_armor_maxed = FALSE
		if(target_wound.sew_progress < target_wound.sew_threshold)
			if(doctor.mind)
				doctor.mind.add_sleep_experience(/datum/skill/misc/medicine, doctor.STAINT * SEW_EXP_PER_STEP)
			continue
		if(doctor.mind)
			var/exp_scale = target_wound.sew_threshold / SEW_HP_EXP_NORMALIZER
			var/base_exp = doctor.STAINT * SEW_EXP_FINISH
			doctor.mind.add_sleep_experience(/datum/skill/misc/medicine, base_exp * exp_scale)
		use(1)
		target_wound.sew_wound()
		if(patient == doctor)
			if(is_simple_animal)
				doctor.visible_message(span_notice("[doctor] sews \a [target_wound.name] on [doctor.p_them()]self."), span_notice("I stitch \a [target_wound.name] on myself."))
			else
				doctor.visible_message(span_notice("[doctor] sews \a [target_wound.name] on [doctor.p_them()]self."), span_notice("I stitch \a [target_wound.name] on my [affecting]."))
		else
			if(is_simple_animal)
				doctor.visible_message(span_notice("[doctor] sews \a [target_wound.name] on [patient]."), span_notice("I stitch \a [target_wound.name] on [patient]."))
			else if(affecting)
				doctor.visible_message(span_notice("[doctor] sews \a [target_wound.name] on [patient]'s [affecting]."), span_notice("I stitch \a [target_wound.name] on [patient]'s [affecting]."))
			else
				doctor.visible_message(span_notice("[doctor] sews \a [target_wound.name] on [patient]."), span_notice("I stitch \a [target_wound.name] on [patient]."))
		if(is_simple_animal)
			var/mob/living/simple_animal/animal_patient = patient
			animal_patient.adjustHealth(-((animal_patient.maxHealth / 20) * (medskill + 1)), TRUE)
		log_combat(doctor, patient, "sew", "needle")
		return TRUE
	return FALSE

/obj/item/needle/thorn
	name = "needle"
	icon_state = "thornneedle"
	desc = "This rough needle can be used to sew cloth and wounds."
	stringamt = 5
	maxstring = 5
	anvilrepair = null

/obj/item/needle/thorn/cleric
	name = "clerical needle"
	icon_state = "lesserneedle"
	desc = "This iron-tipped needle can stem the flow of nastier wounds; a blessing, when one is delivered a grave blow while far away from the Church."
	stringamt = 10
	maxstring = 10
	anvilrepair = null

/obj/item/needle/pestra
	name = "needle of pestra"
	desc = span_green("This needle has been blessed by the goddess of medicine herself!")
	infinite = TRUE

/obj/item/needle/bronze
	name = "bronze needle"
	icon_state = "bronzeneedle"
	desc = "A deceptively long needle with a craned tip, laced for labors-a-plenety."
	stringamt = 30
	maxstring = 30

/obj/item/needle/bronze/communal
	name = "communal bronze needle"
	desc = "A needle left with utmost goodwill intentions, meant to help repair the equipment of those in need. You didn't snatch it for yourself, did you?"

/obj/item/needle/aalloy
	name = "decrepit needle"
	icon_state = "aneedle"
	desc = "This decrepit old needle doesn't seem helpful for much."
	stringamt = 5
	maxstring = 5

#undef SEW_HP_EXP_NORMALIZER
#undef SEW_EXP_PER_STEP
#undef SEW_EXP_FINISH
#undef FIBER_THREAD_USES
