# METADATA
# title: イメージの参照に関する関数
# description: dockerfile と kubernetes のパッケージが使う。deny を持たない。
package lib.image

parse(ref) := {"name": m[1], "tag": m[2], "digest": m[3]} if {
	m := regex.find_all_string_submatch_n(`^(.+?)(?::([^:/]+))?(?:@(.+))?$`, ref, 1)[0]
}

pinned(ref) if {
	parse(ref).digest != ""
}

pinned(ref) if {
	tag := parse(ref).tag
	tag != ""
	tag != "latest"
}

repository(ref) := name if {
	name := parse(ref).name
	contains(name, "/")
	registry_host(split(name, "/")[0])
}

repository(ref) := concat("/", ["docker.io", name]) if {
	name := parse(ref).name
	contains(name, "/")
	not registry_host(split(name, "/")[0])
}

repository(ref) := concat("/", ["docker.io/library", name]) if {
	name := parse(ref).name
	not contains(name, "/")
}

registry_host(s) if contains(s, ".")

registry_host(s) if contains(s, ":")

registry_host("localhost")
