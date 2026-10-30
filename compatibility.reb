Rebol [
	title: "Backward compatibility"
]

;; Backward compatibility:
;; `fail` is native since Rebol 3.22.5; provide a fallback for older versions
fail: any [
	select system/contexts/lib 'fail
	func [
		"Raises the given error or an error with the given message."
		value [string! error!] "Error message or error value"
	][
		do make error! value
	]
]