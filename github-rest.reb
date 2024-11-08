Rebol [
	title: "GitHub REST API"
]

rest: context [
	api.github: https://api.github.com/
	owner:
	repository: none

	data: make map! 4
	response: none

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

		][
			*do 'GET [%repos/ owner %/ repository %/actions/workflows] none
		]
	]

	post: object [
		issue: func[
			data [map!] {title, body, labels etc..}
		][
			unless block? data/labels [ data/labels: reduce [labels] ]
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
			probe data
			*do 'POST [%repos/ owner %/ repository %/labels] data
		]

		release: func[
			tag_name   [string!] "Required. The name of the tag."
			target     [string!] "Specifies the commitish value that determines where the Git tag is created from. Can be any branch or commit SHA. Unused if the Git tag already exists. Default: the repository's default branch (usually master)."
			name       [string!] "The name of the release."
			body       [string! none!] "Text describing the contents of the tag."
			draft      [logic!]  {true to create a draft (unpublished) release, false to create a published one.}
			prerelease [logic!] {true to identify the release as a prerelease. false to identify the release as a full release.}
		][
			clear data
			append data compose [
				tag_name:         (tag_name)
				target_commitish: (target)
				name:             (name)
				draft:            (draft)
				prerelease:       (prerelease)
			]
			? data
			*do 'POST [%repos/ owner %/ repository %/releases] data
		]
	]

	edit: object [
		issue: func[number [integer!] data [map!]][
			*do 'PATCH [%repos/ owner %/ repository %/issues/ number] data
		]
	]

	run: object [
		workflow: func[id][
			clear data
			data/ref: "master"
			data/inputs: make map! 4
			*do 'POST [%repos/ owner %/ repository %/actions/workflows/ id %/dispatches] data
		]
	]

	*do: func[method [word!] path data [map! none!] /local url header][
		url: join api.github path
		;?? url
		header: make map! 4
		unless header/Authorization: user's github-token [
			do make error! "Authorization token (github-token) is missing!"
		]
		header/X-OAuth-Scopes: "repo"
		header/Accept: "Accept: application/vnd.github.v3+json"

		if map? data [header/Content-Type:  "application/json"]
		response: write url reduce [method to block! header to-json data]
		try [response: load-json to string! response]
	]
]