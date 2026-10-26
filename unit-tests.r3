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

summary