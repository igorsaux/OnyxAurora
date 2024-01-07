
//This is a list of words which are ignored by the parser when comparing message contents for names. MUST BE IN LOWER CASE!
var/list/adminhelp_ignored_words = list("unknown","the","a","an","of","monkey","alien","as")

/client/verb/adminhelp(msg as text)
	set category = "Admin"
	set name = "Adminhelp"

	if(say_disabled)	//This is here to try to identify lag problems
		to_chat(usr, "<span class='warning'>Speech is currently admin-disabled.</span>")
		return

	adminhelped = ADMINHELPED

	if(src.handle_spam_prevention(msg,MUTE_ADMINHELP))
		return

	//clean the input msg
	if(!msg)
		return

	msg = sanitize(msg)

	if(!msg)
		return

	// handle ticket
	var/datum/ticket/ticket = get_open_ticket_by_ckey(ckey)
	if(!ticket)
		ticket = new /datum/ticket(ckey)
	else if(ticket.status == TICKET_ASSIGNED)
		// manually check that the target client exists here as to not spam the usr for each logged out admin on the ticket
		var/admin_found = 0
		for(var/admin in ticket.assigned_admins)
			var/client/admin_client = client_by_ckey(admin)
			if(admin_client)
				admin_found = 1
				src.cmd_admin_pm(admin_client, msg, ticket)
				break
		if(!admin_found)
			to_chat(src, "<span class='warning'>Error: Private-Message: Client not found. They may have lost connection, so please be patient!</span>")
		return

	ticket.append_message(src.ckey, null, msg)

	//Options bar:  mob, details ( admin = 2, undibbsed admin = 3, mentor = 4, character name (0 = just ckey, 1 = ckey and character name), link? (0 no don't make it a link, 1 do so),
	//		highlight special roles (0 = everyone has same looking name, 1 = antags / special roles get a golden name)

	msg = "<span class='notice'><b>[create_text_tag("HELP")][get_options_bar(mob, 2, 1, 1, 1, ticket)] (<a href='?_src_=holder;take_ticket=\ref[ticket]'>[(ticket.status == TICKET_OPEN) ? "TAKE" : "JOIN"]</a>) (<a href='?src=\ref[usr];close_ticket=\ref[ticket]'>CLOSE</a>):</b> [msg]</span>"

	var/admin_number_present = 0
	var/admin_number_afk = 0

	for(var/s in GLOB.staff)
		var/client/C = s
		if((R_ADMIN|R_MOD) & C.holder.rights)
			admin_number_present++
			if(C.is_afk())
				admin_number_afk++
			if(C.prefs.toggles & SOUND_ADMINHELP)
				sound_to(C, 'sound/effects/adminhelp.ogg')

			to_chat(C, msg)

	//show it to the person adminhelping too
	to_chat(src, "<span class='notice'>PM to-<b>Staff </b>: [msg]</span>")

	var/admin_number_active = admin_number_present - admin_number_afk
	log_admin("HELP: [key_name(src)]: [msg] - heard by [admin_number_present] non-AFK admins.",admin_key=key_name(src))
	if(admin_number_active <= 0)
		SSdiscord.post_webhook_event(WEBHOOK_ADMIN_PM_IMPORTANT, list("title"="Help is requested", "message"="Request for Help from **[key_name(src)]**: ```[html_decode(original_msg)]```\n[admin_number_afk ? "All admins AFK ([admin_number_afk])" : "No admins online"]!!"))
		SSdiscord.send_to_admins("@here Request for Help from [key_name(src)]: [html_decode(original_msg)] - !![admin_number_afk ? "All admins AFK ([admin_number_afk])" : "No admins online"]!!")
		adminhelped = ADMINHELPED_DISCORD
	feedback_add_details("admin_verb","AH") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
	return
