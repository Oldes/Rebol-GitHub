Rebol [
	title: "Backward compatibility"
]

;; Backward compatibility:
if system/version < 3.22.5 [
	fail: func [
	    {Raises the given error or an error with the given message.}
	    value [string! error!] "error message or error value"
	][
	    do make error! value
	]
]

unless any-function? :print-hline [
	print-hline: :print-horizontal-line
]