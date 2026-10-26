Rebol [
	title: "Rebol/GitHub offline unit tests"
	needs: [json]
]

;;=============================================================================
;; Minimal self-contained harness
;;=============================================================================

test-count: 0
fail-count: 0
skip-count: 0
failed: copy []

group: func ["Starts a named group of tests" name [string!]][
	print ajoin [lf as-yellow "== " as-yellow name]
]

;; NOTE: plain `func` with explicit locals - `function` would collect the
;; counter set-words as locals and the totals would never move.
;;
;; A test block must EVALUATE to true; anything else counts as a failure and
;; is printed as the detail, so a check can hand back a string saying what
;; went wrong. Never use `return` inside one - it would return from
;; `--test--` itself and the result would never be counted.
--test--: func [
	"Passes when the code block evaluates to true"
	name [string!]
	code [block!]
	/local result
][
	test-count: test-count + 1
	result: try code
	case [
		error? :result [
			fail-count: fail-count + 1
			append failed name
			print [as-red "[FAIL]" name]
			print [as-red "      " mold/flat :result]
		]
		:result = true [
			print [as-green "[ ok ]" name]
		]
		true [
			fail-count: fail-count + 1
			append failed name
			print [as-red "[FAIL]" name "=>" mold/flat/part :result 60]
		]
	]
	:result
]

--skip--: func ["Counts a test which cannot run here" name [string!]][
	skip-count: skip-count + 1
	print [as-purple "[skip]" name]
]

--rejects--: func [
	"Checks that the code is refused with an error"
	label [string!]
	code  [block!]
][
	--test-- ajoin [label " is refused"] compose/only [error? try (code)]
]

;; Compares a result with what it should be and hands back the actual value
;; when they differ, so the failure line shows it.
is?: func ["Compares a value with the expected one" value expected][
	any [value == expected  ajoin ["got " mold/flat/part value 60]]
]

summary: does [
	print ajoin [lf as-yellow "-----------------------------------------------------------------------------"]
	print [
		"tests:" test-count
		as-green ajoin ["passed: " test-count - fail-count - skip-count]
		either fail-count > 0 [as-red ajoin ["failed: " fail-count]][ajoin ["failed: " fail-count]]
		as-purple ajoin ["skipped: " skip-count]
	]
	if fail-count > 0 [
		print as-red ajoin ["^/Failed tests:^/  " mold/flat failed]
	]
	print ""
	quit/return either fail-count > 0 [1][0]
]

;;=============================================================================
;; Setup: REST layer only, HTTP mocked
;;=============================================================================

do %github-rest.reb
rest/use-repo "Oldes" "Rebol3"

real-do:     :rest/*do
real-header: :rest/*header
;; Mock the HTTP layer: return what would be sent instead of sending it
rest/*do: func[method path data][reduce [method ajoin path data]]

;;=============================================================================

group "post/issue"

--test-- "single label becomes block" [
	r: rest/post/issue #[title: "T" labels: "bug"]
	is? r/3/labels ["bug"]
]
--test-- "label block is kept" [
	r: rest/post/issue #[title: "T" labels: ["bug" "test"]]
	is? r/3/labels ["bug" "test"]
]
--test-- "no labels key is not added" [
	r: rest/post/issue #[title: "T"]
	is? r/3/labels none
]
--test-- "method and path" [
	r: rest/post/issue #[title: "T"]
	is? reduce [r/1 r/2] [POST %repos/Oldes/Rebol3/issues]
]
--test-- "ref! label becomes block" [
	r: rest/post/issue #[title: "T" labels: @bug]
	is? r/3/labels [@bug]
]
--test-- "ref! label serializes as JSON string" [
	r: rest/post/issue #[title: "T" labels: @bug]
	is? to-json r/3/labels {["bug"]}
]


group "post/release"

--test-- "body is sent" [
	r: rest/post/release "v1" "master" "Name" "Notes" false true
	is? r/3/body "Notes"
]
--test-- "none body is omitted" [
	r: rest/post/release "v1" "master" "Name" none false true
	not find words-of r/3 'body
]
--test-- "other fields" [
	r: rest/post/release "v1" "master" "Name" "Notes" false true
	is? reduce [r/3/tag_name r/3/target_commitish r/3/name r/3/draft r/3/prerelease]
	    reduce ["v1" "master" "Name" false true]
]
--test-- "method and path" [
	r: rest/post/release "v1" "master" "Name" none false false
	is? reduce [r/1 r/2] [POST %repos/Oldes/Rebol3/releases]
]


group "*next-page"

;; HTTP mocks
requests: copy []
rest/*header: does [#[Authorization: "token TEST"]]
rest/*send: func[url request][
	append/only requests reduce [url request]
	reduce [200 #[Content-Type: "application/json"] copy {{"page":2}}]
]
link-next: {<https://api.github.com/x?page=2>; rel="next", <https://api.github.com/x?page=9>; rel="last"}

--test-- "follows next link with auth header" [
	clear requests
	rest/response: reduce [200 compose #[link: (link-next)] ""]
	rest/*next-page
	is? reduce [requests/1/1 requests/1/2/1 requests/1/2/2/Authorization]
	    reduce [https://api.github.com/x?page=2 'GET "token TEST"]
]
--test-- "returns next page body" [
	rest/response: reduce [200 compose #[link: (link-next)] ""]
	r: rest/*next-page
	is? r/page 2
]
--test-- "no next link, no request" [
	clear requests
	rest/response: reduce [200 #[link: {<https://api.github.com/x?page=1>; rel="prev"}] ""]
	is? reduce [rest/*next-page length? requests] [#(none) 0]
]


group "*do 202 retry"

rest/*do: :real-do
rest/retry-delay: 0
statuses: copy []
rest/*send: func[url request][
	append/only requests reduce [url request]
	reduce [any [take statuses 200] #[] copy ""]
]

--test-- "no retry on 200" [
	clear requests  clear statuses
	rest/*do 'GET %x none
	is? length? requests 1
]
--test-- "retries on 202 until 200" [
	clear requests  append clear statuses [202 202 200]
	rest/*do 'GET %x none
	is? length? requests 3
]
--test-- "gives up after max-attempts" [
	clear requests  append clear statuses [202 202 202 202 202]
	rest/max-attempts: 3
	rest/*do 'GET %x none
	rest/max-attempts: 10
	is? reduce [length? requests rest/response/1] [3 202]
]


group "get/artifacts"

;; Mock serving 3 pages, each with 2 artifacts numbered by the page
rest/*send: func[url request /local n][
	append/only requests reduce [url request]
	n: length? requests
	reduce [
		200
		compose #[
			Content-Type: "application/json"
			link: (either n < 3 [ajoin [{<https://api.github.com/p} 1 + n {>; rel="next"}]][""])
		]
		to-json compose #[artifacts: (array/initial 2 n)]
	]
]

--test-- "all pages without limit" [
	clear requests
	is? rest/get/artifacts [1 1 2 2 3 3]
]
--test-- "per_page is capped at 100" [
	clear requests
	rest/get/artifacts/part 500
	did find form requests/1/1 "per_page=100"
]
--test-- "limit satisfied by first page, no more requests" [
	clear requests
	r: rest/get/artifacts/part 2
	is? reduce [r length? requests] [[1 1] 1]
]
--test-- "limit trims across pages" [
	clear requests
	r: rest/get/artifacts/part 3
	is? reduce [r length? requests] [[1 1 2] 2]
]


group "*header"

--test-- "auth headers without X-OAuth-Scopes" [
	saved: :user's
	user's: func['field][if field == 'github-token ["token T"]]
	h: try [real-header]
	user's: :saved
	all [
		map? h
		h/Authorization == "token T"
		none? select h 'X-OAuth-Scopes
	]
]

summary