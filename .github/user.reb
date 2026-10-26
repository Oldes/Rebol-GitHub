Rebol [title: "user options used in CI tests"]

data: get-env 'REBOL_SAFE_FILE
unless data [ print "safe file not found!" quit 1]

try/with [data: debase data 64][
    print "Failed to debase safe file!" quit 2
]

try/with [write %.github-test.safe data][
    print "Failed to save the safe file!" quit 3
]