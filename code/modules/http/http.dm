/proc/http_create_request(method, url, body = "", list/headers)
	var/datum/http_request/R = new()
	R.prepare(method, url, body, headers)

	return R

/proc/httpold_create_get(url, body = "", list/headers)
	return http_create_request(RUSTG_HTTP_METHOD_GET, url, body, headers)

/proc/httpold_create_post(url, body = "", list/headers)
	return http_create_request(RUSTG_HTTP_METHOD_POST, url, body, headers)

/proc/httpold_create_put(url, body = "", list/headers)
	return http_create_request(RUSTG_HTTP_METHOD_PUT, url, body, headers)

/proc/httpold_create_delete(url, body = "", list/headers)
	return http_create_request(RUSTG_HTTP_METHOD_DELETE, url, body, headers)

/proc/httpold_create_patch(url, body = "", list/headers)
	return http_create_request(RUSTG_HTTP_METHOD_PATCH, url, body, headers)

/proc/httpold_create_head(url, body = "", list/headers)
	return http_create_request(RUSTG_HTTP_METHOD_HEAD, url, body, headers)


/**
 * # HTTP Request
 *
 * Holder datum for ingame HTTP requests
 *
 * Holds information regarding to methods used, URL, and response,
 * as well as job IDs and progress tracking for async requests
 */
/datum/http_request
	/// The ID of the request (Only set if it is an async request)
	var/id
	/// Is the request in progress? (Only set if it is an async request)
	var/in_progress = FALSE
	/// HTTP method used
	var/method
	/// Body of the request being sent
	var/body
	/// Request headers being sent
	var/headers
	/// URL that the request is being sent to
	var/url
	/// If present, response body will be saved to this file.
	var/output_file
	/// The raw response, which will be decoeded into a [/datum/http_response]
	var/_raw_response
	/// Callback for executing after async requests. Will be called with an argument of [/datum/http_response] as first argument
	var/datum/callback/cb
	/// Number of retries due to Status 429
	var/retry_count = 0
	/// When this request should be retried
	var/retry_at = 0

/*
###########################################################################
THE METHODS IN THIS FILE ARE TO BE USED BY THE SUBSYSTEM AS A MANGEMENT HUB
----------------------- DO NOT MANUALLY INVOKE THEM -----------------------
###########################################################################
*/

/**
 * Preparation handler
 *
 * Call this with relevant parameters to form the request you want to make
 *
 * Arguments:
 * * method - HTTP Method to use, see code/__DEFINES/rust_g.dm for a full list
 * * url - The URL to send the request to
 * * body - The body of the request, if applicable
 * * headers - Associative list of HTTP headers to send, if applicab;e
 */
/datum/http_request/proc/prepare(method, url, body = "", list/headers, output_file)
	if(!length(headers))
		src.headers = ""
	else
		src.headers = json_encode(headers)

	src.method = method
	src.url = url
	src.body = body
	src.output_file = output_file

/**
 * Blocking executor
 *
 * Remains as a proof of concept to show it works, but should NEVER be used to do FFI halting the entire DD process up
 * Async rqeuests are much preferred, but also require the subsystem to be firing for them to be answered
 */
/datum/http_request/proc/execute_blocking()
	CRASH("Attempted to execute a blocking HTTP request")
	// _raw_response = rustg_http_request_blocking(method, url, body, headers, build_options())

/**
 * Async execution starter
 *
 * Tells the request to start executing inside its own thread inside RUSTG
 * Preferred over blocking, but also requires SShttp to be active
 * As such, you cannot use this for events which may happen at roundstart (EG: IPIntel, BYOND account tracking, etc)
 */
/datum/http_request/proc/begin_async()
	if(in_progress)
		CRASH("Attempted to re-use a request object.")

	id = rustg_http_request_async(method, url, body, headers, build_options())

	if(isnull(text2num(id)))
		_raw_response = "Proc error: [id]"
		CRASH("Proc error: [id]")
	else
		in_progress = TRUE

/**
 * Options builder
 *
 * Builds options for if we want to download files with SShttp
 * Look into the rust_g library to get details on the return values
 */
/datum/http_request/proc/build_options()
	PRIVATE_PROC(TRUE)
	if(output_file)
		return json_encode(list("output_filename" = output_file, "body_filename" = null))
	return null

/**
 * Async completion checker
 *
 * Checks if an async request has been complete
 * Has safety checks built in to compensate if you call this on blocking requests,
 * or async requests which have already finished
 *
 * Returns TRUE if complete, FALSE if not complete
 */
/datum/http_request/proc/is_complete()
	// If we dont have an ID, were blocking, so assume complete
	if(isnull(id))
		return TRUE

	// If we arent in progress, assume complete
	if(!in_progress)
		return TRUE

	// We got here, so check the status
	var/result = rustg_http_check_request(id)

	// If we have no result, were not finished
	if(result == RUSTG_JOB_NO_RESULTS_YET)
		return FALSE
	else
		// If we got here, we have a result to parse
		_raw_response = result
		in_progress = FALSE
		return TRUE

/**
 * Response deserializer
 *
 * Takes a HTTP request object, and converts it into a [/datum/http_response]
 * The entire thing is wrapped in try/catch to ensure it doesnt break on invalid requests
 * Can be called on async and blocking requests
 */
/datum/http_request/proc/into_response()
	RETURN_TYPE(/datum/http_response)
	var/datum/http_response/R = new()

	try
		var/list/L = json_decode(_raw_response)
		R.status_code = L["status_code"]
		R.headers = L["headers"]
		R.body = L["body"]
	catch
		R.errored = TRUE
		R.error = _raw_response

	return R

/**
 * # HTTP Response
 *
 * Holder datum for HTTP responses
 *
 * Created from calling [/datum/http_request/proc/into_response()]
 * Contains vars about the result of the response
 */
/datum/http_response
	/// The HTTP status code of the response
	var/status_code
	/// The body of the response from the server
	var/body
	/// Associative list of headers sent from the server
	var/list/headers
	/// Has the request errored
	var/errored = FALSE
	/// Raw response if we errored
	var/error
