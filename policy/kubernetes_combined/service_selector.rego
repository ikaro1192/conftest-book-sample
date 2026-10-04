# METADATA
# title: Kubernetesマニフェストの組み合わせの規約
# description: "--combine で一つにまとめた複数のドキュメントを検査する。"
package kubernetes_combined

is_combined_kubernetes if {
	is_array(input)
	count(input) > 0
	every doc in input {
		is_string(doc.path)
		is_string(doc.contents.apiVersion)
		is_string(doc.contents.kind)
	}
}

resources contains doc.contents if {
	is_combined_kubernetes
	some doc in input
}

pod_template_kinds := {"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet"}

pod_template_labels contains labels if {
	some r in resources
	r.kind in pod_template_kinds
	labels := object.get(r, ["spec", "template", "metadata", "labels"], {})
}

# METADATA
# scope: rule
# title: Serviceのselectorに一致するPodテンプレートを置く
# description: Service の spec.selector のすべてのラベルを持つPodテンプレートが、同じ入力にある。
# custom:
#   remediation: selector を、接続先のPodテンプレートの labels に合わせる。
deny contains msg if {
	some r in resources
	r.kind == "Service"
	selector := r.spec.selector
	not selects_any_pod(selector)
	msg := sprintf("Service/%s: selector %v does not match any pod template labels", [r.metadata.name, selector])
}

selects_any_pod(selector) if {
	some labels in pod_template_labels
	every key, value in selector {
		labels[key] == value
	}
}
