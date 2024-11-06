Rebol [
  title: "Some useful GitHub GraphQL queries"
]

last-20-closed-issues: {
  query($owner:String!,$repo:String!) {
    repository(owner:$owner, name:$repo) {
      issues(last:20, states:CLOSED) {
        edges {
          node {
            title
            url
            labels(first:5) {
              edges {
                node {
                  name
} } } } } } } } }

repo-labels: {
  query($owner:String!,$repo:String!) {
    repository(owner:$owner, name:$repo) {
      labels(first:100){
        edges {
          node {
            name
            description
            color
} } } } } }

repo-disk-usage: {
  query ($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
    diskUsage
} } }

list-issues: {
    totalCount
    pageInfo {
      endCursor
    }
    edges {
      node {
        title
        url
        body
        author {login}
        closed
        timelineItems(first: 100) {
          nodes {
            __typename
            ... on IssueComment {
              createdAt
              author {
                login
              }
              body
            }
            ... on CrossReferencedEvent {
              createdAt
              actor {
                login
              }
              url
              source {
                __typename
                ... on Issue {
                  title
                  url
                  id
                }
                ... on PullRequest {
                  title
                  body
                  permalink
                }
              }
              target {
                __typename
                ... on Issue {
                  title
                  url
                  id
                }
                ... on PullRequest {
                  title
                  body
                  permalink
                }
              }
            }
            ... on ClosedEvent {
              createdAt
              actor {
                login
              }
              url
              closer {
                __typename
                ... on PullRequest {
                  number
                  title
                }
                ... on Commit {
                  committedDate
                  id
                  committer {
                    name
                  }
                  commitUrl
                  messageHeadline
                  messageBody
                }
              }
            }
            ... on RenamedTitleEvent {
              createdAt
              actor {login}
              currentTitle
              previousTitle
            }
            ... on MarkedAsDuplicateEvent {
              createdAt
              actor {login}
            }
            ... on LabeledEvent {
              createdAt
              actor {login}
              label {name}
            }
            ... on UnlabeledEvent {
              createdAt
              actor{login}
              label {name}
            }
            ... on SubscribedEvent {
              createdAt
              actor {login}
            }
            ... on UnsubscribedEvent {
              createdAt
              actor {login}
            }
            ... on CommentDeletedEvent {
              createdAt
              actor {login}
            }
            ... on LockedEvent {
              createdAt
              actor {login}
              lockReason
            }
            ... on UnlockedEvent {
              createdAt
              actor {login}
            }
            ... on ReopenedEvent {
              createdAt
              actor {
                login
              }
            }
            ... on ReferencedEvent {
              createdAt
              actor {
                login
              }
              commit {
                committedDate
                id
                committer {
                  name
                }
                commitUrl
                messageHeadline
                messageBody
              }
              commitRepository {
                id
              }
              isCrossRepository
              isDirectReference
            }
            ... on MentionedEvent {
              createdAt
              actor {
                login
              }
              id
            }
          }
        }
        labels(first: 5) {
          edges {
            node {
              name
            }
          }
        }
      }
    }
  }

first-100-issues: replace {
  query($owner:String!,$repo:String!) {
    repository(owner:$owner, name:$repo) {
      issues(first:100) {
      #ISSUES#
} } } } "#ISSUES#" :list-issues

next-100-issues: replace {
  query($owner:String!,$repo:String!,$after_issue:String!) {
    repository(owner:$owner, name:$repo) {
      issues(first:100, after:$after_issue) {
      #ISSUES#
} } } } "#ISSUES#" :list-issues

last-10-commits: {
  query($owner:String!,$repo:String!) {
    repository(owner:$owner, name:$repo) {
  ... on Repository {
      defaultBranchRef {
        target {
          ... on Commit {
            history(first: 10) {
              pageInfo {
                endCursor
                hasNextPage
              }
              edges {
                node {
                  ... on Commit {
                    oid
                    committedDate
                    messageHeadline
                    messageBody
} } } } } } } } } } }

next-100-commits: {
  query($owner:String!,$repo:String!, $after:String!) {
    repository(owner:$owner, name:$repo) {
  ... on Repository {
      defaultBranchRef {
        target {
          ... on Commit {
            history(first: 100, after: $after) {
              pageInfo {
                endCursor
                hasNextPage
              }
              edges {
                node {
                  ... on Commit {
                    oid
                    committedDate
                    messageHeadline
                    messageBody
} } } } } } } } } } }

repo-labels: {
  query($owner:String!,$repo:String!) {
  repository(owner:$owner, name:$repo) {
    labels(first:100){
    edges {
      node {
      name
      description
      color
} } } } } }

releases: {
  query ($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      releases(first: 10) {
        edges {
          node {
            id
            name
            url
          }
        }
      }
    }
  }
}