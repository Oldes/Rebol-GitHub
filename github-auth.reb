Rebol [
	title: "GitHub authorization"
]

*token: func[
	"Returns the GitHub Authorization header value (raises an error when missing)"
	/local env
][
	any [
		user's github-token  ;; stored with its scheme, e.g. "token ..." or "Bearer ..."
		all [
			env: get-env "GITHUB_TOKEN"
			not empty? env
			ajoin ["Bearer " env]
		]
		fail "Authorization token (github-token) is missing!"
	]
]