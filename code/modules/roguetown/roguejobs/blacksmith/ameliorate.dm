/obj/machinery/ameliorate
	icon = 'icons/roguetown/misc/forge.dmi'
	name = "ameliorate"
	desc = "A mixture of artifice and smithing, made easy enough to use for anyone. This will clear up any dents or small tears made in armor, making it new again. Fitted light armor will end up ruined, however."
	icon_state = "anvil"
	max_integrity = 200
	density = TRUE
	damage_deflection = 25
	climbable = TRUE
	pass_flags_self = LETPASSTHROW
	var/in_use = FALSE
	var/use_delay = 2.5 SECONDS

/obj/machinery/ameliorate/attackby(obj/item/I, mob/user, params)
	if(!user || !I)
		return

	if(user.cmode)
		. = ..()
		return

	if(in_use)
		to_chat(user, span_warning("It's currently being used!"))
		return

	var/sfx
	if(I.anvilrepair)
		sfx = 'sound/repair/ameliorate_metal.ogg'
	else
		sfx = 'sound/repair/ameliorate_leather.ogg'

	var/datum/component/fit_clothing/has_fitting = I.GetComponent(/datum/component/fit_clothing)
	if(I.max_integrity != initial(I.max_integrity))
		if(sfx)
			playsound(src, sfx, 100, TRUE)
		in_use = TRUE
		if(do_after(user, use_delay, TRUE, same_direction = TRUE))
			I.max_integrity = initial(I.max_integrity)
			if(has_fitting)
				has_fitting.Destroy()
			in_use = FALSE
