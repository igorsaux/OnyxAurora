/// Tests that all subsystems that need to properly initialize.
/datum/unit_test/subsystem_init
	name = "Controller Subsystem Init"
	groups = list("generic")

/datum/unit_test/subsystem_init/start_test()
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		if(subsystem.flags & SS_NO_INIT)
			continue
		if(!(subsystem.initialized))
			var/message = "[subsystem] ([subsystem.type]) is a subsystem meant to initialize but doesn't get set as initialized."

			if (subsystem.flags & SS_OK_TO_FAIL_INIT)
				TEST_NOTICE("[src] - [message]\nThis subsystem is marked as SS_OK_TO_FAIL_INIT. This is still a bug, but it is non-blocking.")
			else
				return TEST_FAIL(message)

	return TEST_PASS("All subsystems initialize correctly.")
