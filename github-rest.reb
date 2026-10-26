Rebol [
	title: "GitHub REST API"
]

rest: context [
	api.github: https://api.github.com/
	owner:
	repository: none

	data: make map! 4
	response: none

	max-attempts: 10       ;; max requests while the server answers 202 (Accepted)
	retry-delay:  0:0:2    ;; wait between them

	use-repo: func[o r][ owner: o repository: r] 

	get: object [
		issues: func[][
			*do 'GET [%repos/ owner %/ repository %/issues] none
		]
		issue: func[number [integer!]][
			*do 'GET [%repos/ owner %/ repository %/issues/ number] none
		]
		issue-comments: func[
			{Gets all comments of an issue by its number}
			number [integer!]
		][
			*do 'GET [%repos/ owner %/ repository %/issues/ number %/comments] none
		]
		issue-labels: func[
			{Gets all labels of an issue by its number}
			number [integer!]
		][
			*do 'GET [%repos/ owner %/ repository %/issues/ number %/labels] none
		]

		current-user: does [*do 'GET %user none]

		workflows: func[
			"Lists the workflows in a repository."
		][
			*do 'GET [%repos/ owner %/ repository %/actions/workflows] none
		]

		artifacts: func [
			"Lists all artifacts for a repository."
			/part limit [integer!] "Limits number of received artifacts to a given length"
			/local path artifacts tmp
		][
			path: ajoin [%repos/ owner %/ repository %/actions/artifacts]
			append path ajoin ["?per_page=" min 100 max 1 any [limit 100]]
			artifacts: make block! 100
			response: *send api.github/:path reduce ['GET *header]
			all [
				map?   tmp: *response-body
				block? tmp: tmp/artifacts
				append artifacts tmp
			]
			while [all [
				any [none? limit  limit > length? artifacts] ;; stop before fetching more than needed
				map?   tmp: *next-page
				block? tmp: tmp/artifacts
			]][
				append artifacts tmp
			]
			if all [limit  limit < length? artifacts][
				clear skip artifacts limit ;; limit output to the requested length
			]
			artifacts
		]

		page-views: func[
			"Get the total number of views and breakdown per day or week for the last 14 days."
			/week
		][
			*do 'GET [
				%repos/ owner %/ repository
				%/traffic/views?per= either/only week %week %day
			] none
		]
		popular-paths: func[
			"Get the top 10 popular contents over the last 14 days."
		][
			*do 'GET [%repos/ owner %/ repository %/traffic/popular/paths] none
		]
		popular-referrers: func[
			"Get the top 10 referrers over the last 14 days."
		][
			*do 'GET [%repos/ owner %/ repository %/traffic/popular/referrers] none
		]
		contributors: func[
			"Returns the total number of commits authored by the contributor"
		][
			*do 'GET [%repos/ owner %/ repository %/stats/contributors] none
		]

		emojis: func[
			"Lists all the emojis available to use on GitHub."
		][
			*do 'GET %emojis none
		]
	]

	post: object [
		issue: func[
			"Creates an issue"
			data [map!] "title, body, labels etc.."
		][
			if any-string? data/labels [data/labels: reduce [data/labels]]
			*do 'POST [%repos/ owner %/ repository %/issues] data
		]

		issue-comment: func[
			{Adds a comment to an issue by its number}
			number  [integer!]
			body    [string!]
		][
			clear data
			data/body: body
			*do 'POST [%repos/ owner %/ repository %/issues/ number %/comments] data
		]

		issue-label: func[
			{Adds a label(s) to an issue by its number}
			number  [integer!]
			label   [string! block!]
		][
			clear data
			append data/labels: clear [] label
			*do 'POST [%repos/ owner %/ repository %/issues/ number %/labels] data
		]

		label: func[
			{Creates a label}
			name  [string!]
			desc  [string!]
			color [string!]
		][
			clear data
			data/name: name
			data/description: desc
			data/color: color 
			*do 'POST [%repos/ owner %/ repository %/labels] data
		]

		release: func[
			"Creates a release"
			tag_name   [string!] "Required. The name of the tag."
			target     [string!] "Specifies the commitish value that determines where the Git tag is created from. Can be any branch or commit SHA. Unused if the Git tag already exists."
			name       [string!] "The name of the release."
			body       [string! none!] "Text describing the contents of the tag."
			draft      [logic!]  {true to create a draft (unpublished) release, false to create a published one.}
			prerelease [logic!] {true to identify the release as a prerelease. false to identify the release as a full release.}
		][
			clear data
			data/tag_name:         tag_name
			data/target_commitish: target
			data/name:             name
			if body [data/body:    body]
			data/draft:            draft
			data/prerelease:       prerelease
			*do 'POST [%repos/ owner %/ repository %/releases] data
		]

		markdown: func[
			"Render a Markdown document"
			text  [string!] "The Markdown text to render in HTML."
			/context
			 repo [string! path! none!] "The repository context to use when creating references."
		][
			clear data
			data/text: text
			if context [
				data/mode: "gfm"
				data/context: repo
			]
			*do 'POST %markdown data
		]
	]

	edit: object [
		issue: func[number [integer!] data [map!]][
			*do 'PATCH [%repos/ owner %/ repository %/issues/ number] data
		]
	]

	run: object [
		workflow: func[
			"Triggers a workflow_dispatch event for a workflow."
			id [integer! string!] "Workflow ID or file name (e.g. main.yml)"
			/ref branch [any-string!] "Git reference (branch or tag); default: main"
		][
			clear data
			data/ref: any [branch @main]
			data/inputs: make map! 4
			*do 'POST [%repos/ owner %/ repository %/actions/workflows/ id %/dispatches] data
		]
	]

	;- Internal functions...
	*send: func[
		"Sends an HTTP request and returns [status headers body]"
		url     [url!]
		request [block!]
	][
		write/all url request
	]
	*do: func[method [word!] path data [map! none!] /local header tries][
		header: *header
		if map? data [
			header/Content-Type:  "application/json"
			data: to-json data
		]
		if block? path [path: ajoin path]
		;; When the server responds with 202 (Accepted), wait and retry (limited).
		tries: max-attempts
		while [
			response: *send api.github/:path reduce [method header data]
			all [response/1 == 202  0 < tries: tries - 1]
		][	wait retry-delay ]
		*response-body
	]
	*header: function[][
		header: clear #[]
		unless header/Authorization: user's github-token [
			do make error! "Authorization token (github-token) is missing!"
		]
		header/Accept: "application/vnd.github+json"
		header/X-GitHub-Api-Version: "2022-11-28"
		header
	]
	*next-page: func[/local links link url rel][
		links: clear #[]
		if all [
			string? link: select response/2 'link
			parse link [
				any [
					thru #"<" copy url: to #">"
					thru {; rel="} copy rel: to {"} (
						rel: to word! rel
						links/:rel: as url! url
					)
				] to end
				;(?? links)
			]
			links/next
		][
			response: *send links/next reduce ['GET *header]
			*response-body
		]
	]
	*response-body: func[/local tmp type][
		;; Uncertain if it's a bug in Rebol's HTTP handling or in Github, but GitHub's error responses
		;; sometimes lack Content-Length and include trailing bytes instead. Remove them if found.
		if "^A^@" == tmp: skip tail response/3 -2 [clear tmp]
		;; Not all responses are in JSON format!
		if all [
			type: select response/2 'Content-Type
			find type "json"
		][
			response/3: load-json response/3
		]
		response/3
	]
]