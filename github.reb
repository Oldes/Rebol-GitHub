Rebol [
	type:  module
	name:  github
	needs: json
	title: "Rebol/GitHub utilities"
	version: 0.2.0
	date:  8-Nov-2024
	home:  https://github.com/Oldes/Rebol-GitHub
	exports: [
		github-query
		github-repo
		github-run
		github-get
		github-post
		github-edit
	]
]

#include %github-rest.reb    ;; GitHub REST API
#include %github-graphql.reb ;; GitHub GraphQL API

;- GraphQL:
;; https://docs.github.com/en/graphql
github-query: :graphql/request

;- REST:
;; https://docs.github.com/en/rest?apiVersion=2022-11-28	
github-repo: func[
	"Initialize the repository used for REST API calls."
	repo [block! path!]
][
	:rest/use-repo first repo second repo
]
github-run:  :rest/run
github-get:  :rest/get
github-post: :rest/post
github-edit: :rest/edit
