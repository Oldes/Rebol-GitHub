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
do %github-graphql.reb
rest/use-repo "Oldes" "Rebol3"

real-do:     :rest/*do
real-header: :rest/*header
;; Mock the HTTP layer: return what would be sent instead of sending it
rest/*do: mock-do: func[method path data][
	reduce [method either block? path [ajoin path][path] data]
]

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
--test-- "caller's map is not modified" [
	m: #[title: "T" labels: "bug"]
	rest/post/issue m
	is? m/labels "bug"
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


group "run/workflow"
rest/*do: :mock-do

--test-- "default ref is master" [
	r: rest/run/workflow "main.yml"
	is? r/3/ref @main
]
--test-- "/ref sets the branch" [
	r: rest/run/workflow/ref "main.yml" "master"
	is? r/3/ref "master"
]
--test-- "/ref accepts ref!" [
	r: rest/run/workflow/ref "main.yml" @dev
	is? to-json r/3 {{"ref":"dev","inputs":{}}}
]
--test-- "method and path" [
	r: rest/run/workflow 123
	is? reduce [r/1 r/2] [POST %repos/Oldes/Rebol3/actions/workflows/123/dispatches]
]


group "post/markdown"
rest/*do: :mock-do

--test-- "path! context is sent as string" [
	r: rest/post/markdown/context "x" 'Oldes/Rebol3
	is? r/3/context "Oldes/Rebol3"
]
--test-- "string context" [
	r: rest/post/markdown/context "x" "Oldes/Rebol3"
	is? reduce [r/3/context r/3/mode] ["Oldes/Rebol3" "gfm"]
]
--test-- "no context, no mode" [
	r: rest/post/markdown "x"
	all [none? r/3/context  none? r/3/mode]
]
--test-- "method and path" [
	r: rest/post/markdown "x"
	is? reduce [r/1 r/2] [POST %markdown]
]


group "get/pages"

rest/*do: :mock-do

--test-- "method and path" [
	r: rest/get/pages
	is? reduce [r/1 r/2 r/3] [GET %repos/Oldes/Rebol3/pages #(none)]
]


group "REST errors"

rest/*do: :real-do
status: 200
body: none
rest/*send: func[url request][
	reduce [status #[Content-Type: "application/json"] copy body]
]

--test-- "4xx raises error with GitHub message" [
	status: 404  body: {{"message":"Not Found"}}
	e: try [rest/get/pages]
	all [error? e  did find form e "Not Found"]
]
--test-- "5xx raises error" [
	status: 500  body: {{"message":"Server Error"}}
	error? try [rest/get/pages]
]
--test-- "2xx returns decoded body" [
	status: 200  body: {{"ok":true}}
	r: rest/get/pages
	is? r/ok true
]



group "GraphQL"

graphql/retry-delay: 0
saved-users: :user's
user's: func['field][if field == 'github-token ["token T"]]

calls: 0
replies: copy []
graphql/*send: func[url request /local r][
	calls: calls + 1
	r: take replies
	if error? r [do r]
	r
]
reply: func[status json][reduce [status #[] to binary! json]]
setup: func[list][calls: 0  append clear replies reduce list]

--test-- "returns decoded data" [
	setup [reply 200 {{"data":{"a":1}}}]
	r: graphql/request "q" none
	is? r/data/a 1
]
--test-- "errors without data raise error" [
	setup [reply 200 {{"data":null,"errors":[{"message":"Bad query"}]}}]
	e: try [graphql/request "q" none]
	all [error? e  did find form e "Bad query"]
]
--test-- "4xx is not retried" [
	setup [reply 401 {{"message":"Bad credentials"}}  reply 200 {{"data":{}}}]
	e: try [graphql/request "q" none]
	all [error? e  calls == 1]
]
--test-- "5xx is retried" [
	setup [reply 502 "" reply 200 {{"data":{"a":1}}}]
	r: graphql/request "q" none
	is? reduce [calls r/data/a] [2 1]
]
--test-- "network error is retried" [
	setup [make error! "net down"  reply 200 {{"data":{"a":1}}}]
	r: graphql/request "q" none
	is? calls 2
]
--test-- "gives up after max-attempts" [
	setup [reply 502 "" reply 502 "" reply 502 "" reply 502 ""]
	e: try [graphql/request "q" none]
	all [error? e  calls == 3]
]
--test-- "unknown query name returns none" [
	setup []
	is? graphql/request 'no-such-query none #(none)
]

user's: :saved-users

summary