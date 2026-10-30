Rebol [
	title:   "Transfer GitHub issues between repositories"
	purpose: "Moves issues (with comments and labels) using the GraphQL `transferIssue` mutation"
	usage:   {rebol3 transfer-issues.r3 <owner/from-repo> <owner/to-repo> [--all] [--apply]}
	note:    {
		Token rights needed:
		* Contents - R+W
		* Issues   - R+W
		* Metadata
	}
]

import 'github


args: any [system/options/args []]
if 2 > length? args [
	print system/script/header/usage
	quit/return 1
]
source-repo: split args/1 #"/"
target-repo: split args/2 #"/"
apply?: did find args "--apply"
states: either find args "--all" [["OPEN" "CLOSED"]][["OPEN"]]

repo-id-query: {
  query($owner:String!,$repo:String!) {
    repository(owner:$owner, name:$repo) { id }
}}

issues-query: {
  query($owner:String!,$repo:String!,$states:[IssueState!],$after:String) {
    repository(owner:$owner, name:$repo) {
      issues(first:100, after:$after, states:$states, orderBy:{field:CREATED_AT, direction:ASC}) {
        pageInfo { endCursor hasNextPage }
        nodes { id number title labels(first:20) { nodes { name } } }
} } }}

transfer-mutation: {
  mutation($issue:ID!,$repo:ID!) {
    transferIssue(input:{issueId:$issue, repositoryId:$repo, createLabelsIfMissing:true}) {
      issue { number url }
} }}

;;-- Resolve the target repository ID
res: github-query repo-id-query compose #[owner: (target-repo/1) repo: (target-repo/2)]
unless target-id: attempt [res/data/repository/id][
	print [as-red "Target repository not found:" args/2]
	quit/return 1
]

;;-- Collect issues to transfer (all pages)
vars: compose #[owner: (source-repo/1) repo: (source-repo/2) states: (states)]
issues: copy []
prin "^/Collecting issues: 0"
forever [
	res: github-query issues-query vars
	unless page: attempt [res/data/repository/issues][
		print [LF as-red "Source repository not found:" args/1]
		quit/return 1
	]
	append issues page/nodes
	prin ["^MCollecting issues:" as-yellow length? issues]
	unless page/pageInfo/hasNextPage [break]
	vars/after: page/pageInfo/endCursor
]
print LF

print ["Issues to transfer from" as-green args/1 "to" as-green args/2 ":" as-yellow length? issues]
foreach i issues [
	print [pad i/number 6 i/title as-purple collect [foreach l i/labels/nodes [keep l/name]]]
]
unless apply? [
	print as-yellow "Dry run only. Use --apply to transfer."
	quit
]


;;-- Transfer
status: func["Redraws the bottom status line" text [string!]][
	prin ajoin ["^M^[[K" text]
]
say: func["Prints a line above the status line" value][
	prin "^M^[[K"
	print value
]
transfer: func[
	"Transfers one issue, retrying with backoff while GitHub reports it was too quick"
	issue-id [string!]
	/local res delay
][
	delay: 0:1:00
	forever [
		res: try [github-query transfer-mutation compose #[issue: (issue-id) repo: (target-id)]]
		unless all [
			map? res
			block? res/errors
			did find mold res/errors "submitted too quickly"
		][return res]
		repeat s to integer! delay [
			status as-yellow ajoin [
				"    submitted too quickly, retrying in " 1 + (to integer! delay) - s "s"
			]
			wait 1
		]
		delay: min 0:10:00 delay * 2
	]
]

total:  length? issues
failed: 0
n:      0
start:  now/precise
foreach i issues [
	n: n + 1
	status ajoin ["[" n "/" total "] transferring #" i/number "..."]
	res: transfer i/id
	either all [not error? res  new: attempt [res/data/transferIssue/issue]][
		say ajoin ["[" n "/" total "] #" i/number " -> " new/url]
	][
		failed: failed + 1
		say [as-red ajoin ["[" n "/" total "] #" i/number " FAILED: "] i/title]
		say either error? res [res][mold/flat res/errors]
	]
	elapsed: difference now/precise start
	status as-gray ajoin [
		"[" n "/" total "] elapsed: " elapsed
		"  remaining: ~" elapsed / n * (total - n)
	]
	wait 0:0:3 ;; GitHub limits content creation; 1s between mutations is not enough
]
say ["Transferred:" total - failed "failed:" failed "time:" difference now/precise start]
if failed > 0 [quit/return 1]