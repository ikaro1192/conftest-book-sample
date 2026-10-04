package kubernetes

exceptable_rules := {"read_only_root_filesystem"}

exception contains rules if {
	some e in data.exceptions.kubernetes
	e.resource == resource_id
	e.reason != ""
	time.now_ns() < time.parse_rfc3339_ns(e.expires)
	rules := [rule | some rule in e.rules; rule in exceptable_rules]
	count(rules) > 0
}
