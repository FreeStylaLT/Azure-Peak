/obj/item/repair_kit
	name = "sewing kit"
	icon_state = "sewingkit"
	desc = "A well-made repair kit that includes high-quality reinforced fabric lines and leather patches for field repairs. It can patch up gashes in leather-and-cloth without the need for a tailor's needle."
	icon = 'icons/roguetown/items/misc.dmi'
	lefthand_file = 'icons/mob/inhands/misc/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/food_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	force = 0
	throwforce = 0
	resistance_flags = FLAMMABLE
	slot_flags = ITEM_SLOT_HIP
	max_integrity = 5
	experimental_inhand = FALSE
	var/table_need = TRUE
	var/repair_type = 0 //0 - cloth; 1 - metal
	var/in_use = FALSE
	dropshrink = 0.7
	grid_width = 64
	grid_height = 32

/obj/item/repair_kit/examine()
	. = ..()
	if(src.obj_integrity > 0)
		. += span_bold("It has [src.obj_integrity] left.")
	else
		. += span_bold("It has no uses left.")

/obj/item/repair_kit/proc/self_del()
	if(repair_type == 0)
		if(prob(50))
			new /obj/item/natural/cloth(get_turf(src))
		if(prob(40))
			new /obj/item/natural/fibers(get_turf(src))
		if(prob(20))
			new /obj/item/natural/fibers(get_turf(src))
	if(repair_type == 1)
		if(prob(20))
			new /obj/item/scrap(get_turf(src))
	qdel(src)

/obj/item/repair_kit/attack_obj(obj/O, mob/living/user)
	if(!isitem(O) || in_use)
		return
	var/obj/item/I = O
	if(src.obj_integrity <= 0)
		if(I.sewrepair)
			playsound(loc, 'sound/foley/cloth_rip.ogg', 100, TRUE, -2)
		if(I.anvilrepair)
			playsound(loc,'sound/items/bsmithfail.ogg', 100, TRUE, -2)
		self_del()
		return
	if(I.sewrepair && repair_type == 1)
		return
	if(I.anvilrepair && repair_type == 0)
		return
	if(I.max_integrity)
		if(I.obj_integrity != I.max_integrity)
			to_chat(user, span_warning("This requires more repairs."))
			return
		if(initial(I.max_integrity) == I.max_integrity)
			to_chat(user, span_warning("This item is already in top shape."))
			return
		if(!I.ontable() && table_need == TRUE)
			to_chat(user, span_warning("I should put this on a table first."))
			return
		if(I.sewrepair)
			playsound(loc, 'sound/repair/ameliorate_leather.ogg', 100, TRUE, -2)
		if(I.anvilrepair)
			playsound(loc,'sound/repair/ameliorate_metal.ogg', 100, TRUE, -2)
		var/const/AUTO_SEW_DELAY = CLICK_CD_MELEE
		in_use = TRUE
		if(!do_after(user, 2 SECONDS, target = I))
			in_use = FALSE
			return
		I.max_integrity = initial(I.max_integrity)
		take_damage(1, BRUTE)
		return
	return ..()

/obj/item/repair_kit/bad
	name = "fabric patch"
	icon_state = "custarsewingkit"
	desc = "A meager set of pieces of cloth, a bundle of threads and a loose rope. It can be used for field repairs."
	max_integrity = 1
	grid_width = 32
	grid_height = 32

/obj/item/repair_kit/metal
	name = "armor plates"
	icon_state = "armorkit"
	desc = "A wonderful set of metal patches, individual armor plates and straps for fastening them. It can be used to properly damaged weapons and armor, without the need for a blacksmith's hammer."
	repair_type = 1
	max_integrity = 5

/obj/item/repair_kit/metal/bad
	name = "metal scrap kit"
	icon_state = "custararmorkit"
	desc = "A meager set of metal patches, repurposed iron shingles and straps for fastening them. It can be used to repair damaged weapons and armor in a pinch, without the need for a blacksmith's hammer. It can also be used in smithing to create banded iron pieces."
	max_integrity = 1

/obj/item/scrap
	name = "iron scrap"
	desc = "Shingles and scrap, born from violence upon iron. There may yet still be a use for these pieces.. </br>Iron scrap can be crafted into metal repair kits, which - when stuffed with iron scrap - can repair damaged equipment without the need for a blacksmith's hammer."
	icon_state = "scrap"
	icon = 'icons/roguetown/items/misc.dmi'
	grid_width = 32
	grid_height = 32
	dropshrink = 0.7
	anvilrepair = /datum/skill/craft/blacksmithing //for empty kit code

/obj/item/scrap/attack(mob/living/M, mob/user)
	if(!user.cmode)
		if(try_construct_consume(src, M, user))
			return
		else
			return ..()
	else
		return ..()
