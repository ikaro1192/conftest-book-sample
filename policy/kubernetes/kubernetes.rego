# METADATA
# title: Kubernetesマニフェストの規約
# description: Kubernetesマニフェストの一つのドキュメントを検査する。--combine を指定せずに使う。
package kubernetes

import data.lib.image

is_kubernetes if {
	is_string(input.apiVersion)
	is_string(input.kind)
}

resource_id := sprintf("%s/%s", [input.kind, object.get(input, ["metadata", "name"], "")]) if is_kubernetes

pod_template_kinds := {"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job"}

pod_spec := input.spec.template.spec if {
	is_kubernetes
	input.kind in pod_template_kinds
}

pod_spec := input.spec.jobTemplate.spec.template.spec if {
	is_kubernetes
	input.kind == "CronJob"
}

pod_spec := input.spec if {
	is_kubernetes
	input.kind == "Pod"
}

containers contains container if {
	some container in pod_spec.containers
}

containers contains container if {
	some container in pod_spec.initContainers
}

# METADATA
# scope: rule
# title: 特権コンテナを使わない
# description: コンテナの securityContext.privileged を true にしない。
# related_resources:
#   - ref: https://kubernetes.io/docs/concepts/security/pod-security-standards/
# custom:
#   remediation: securityContext.privileged を削除するか、false にする。
deny contains msg if {
	some container in containers
	container.securityContext.privileged == true
	msg := sprintf("%s: container %q must not run in privileged mode", [resource_id, container.name])
}

# METADATA
# scope: rule
# title: ノードの名前空間を共有しない
# description: Pod の hostNetwork・hostPID・hostIPC を true にしない。
# related_resources:
#   - ref: https://kubernetes.io/docs/concepts/security/pod-security-standards/
# custom:
#   remediation: これらのフィールドを削除するか、false にする。
deny contains msg if {
	some field in ["hostNetwork", "hostPID", "hostIPC"]
	pod_spec[field] == true
	msg := sprintf("%s: pod must not set %s to true", [resource_id, field])
}

# METADATA
# scope: rule
# title: CPUとメモリのrequestsとlimitsを指定する
# description: initContainers を含むすべてのコンテナで、resources.requests と resources.limits の cpu と memory を指定する。
# related_resources:
#   - ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
# custom:
#   remediation: resources に requests と limits の cpu と memory の四つの値を書く。
deny contains msg if {
	some container in containers
	some kind in ["requests", "limits"]
	some name in ["cpu", "memory"]
	not container.resources[kind][name]
	msg := sprintf("%s: container %q must set resources.%s.%s", [resource_id, container.name, kind, name])
}

# METADATA
# scope: rule
# title: コンテナイメージのタグを固定する
# description: コンテナの image に、latest 以外のタグかダイジェストを指定する。
# custom:
#   remediation: "v0.1.0 のようにタグを書くか、@sha256: に続けてダイジェストを書く。"
deny contains msg if {
	some container in containers
	not image.pinned(container.image)
	msg := sprintf(
		"%s: container %q image %q must not use the \"latest\" tag",
		[resource_id, container.name, container.image],
	)
}

# METADATA
# scope: rule
# title: コンテナをroot以外のユーザーで実行する
# description: Pod かコンテナの securityContext.runAsNonRoot を true にする。コンテナの値は、Pod の値より優先される。
# related_resources:
#   - ref: https://kubernetes.io/docs/concepts/security/pod-security-standards/
# custom:
#   remediation: "Pod の securityContext に runAsNonRoot: true を書く。イメージの USER が nonroot のような名前の場合は、runAsUser に数値のUIDも書く。"
deny contains msg if {
	some container in containers
	not run_as_non_root(container)
	msg := sprintf("%s: container %q must set runAsNonRoot to true", [resource_id, container.name])
}

run_as_non_root(container) if {
	pod_default := object.get(pod_spec, ["securityContext", "runAsNonRoot"], false)
	object.get(container, ["securityContext", "runAsNonRoot"], pod_default) == true
}

# METADATA
# scope: rule
# title: ルートファイルシステムを読み取り専用にする
# description: コンテナの securityContext.readOnlyRootFilesystem を true にする。この規約は、data.exceptions.kubernetes で例外にできる。
# custom:
#   remediation: "readOnlyRootFilesystem: true を書く。書き込みが必要なディレクトリには、emptyDir のボリュームをマウントする。"
deny_read_only_root_filesystem contains msg if {
	some container in containers
	not container.securityContext.readOnlyRootFilesystem == true
	msg := sprintf("%s: container %q must set readOnlyRootFilesystem to true", [resource_id, container.name])
}

# METADATA
# scope: rule
# title: defaultのServiceAccountを使わない
# description: Pod の serviceAccountName を指定し、default 以外とする。
# custom:
#   remediation: アプリケーション専用の ServiceAccount を作り、serviceAccountName に指定する。
deny contains msg if {
	not dedicated_service_account(pod_spec)
	msg := sprintf("%s: pod must not use the default ServiceAccount", [resource_id])
}

dedicated_service_account(spec) if {
	spec.serviceAccountName != "default"
}

# METADATA
# scope: rule
# title: IRSAのIAMロールを許可リストに限る
# description: ServiceAccount の eks.amazonaws.com/role-arn は、data.allowlist.kubernetes_irsa_role_arn_prefixes のいずれかで始まる。
# related_resources:
#   - ref: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
# custom:
#   remediation: 許可リストの接頭辞で始まるIAMロールを使う。
deny contains msg if {
	is_kubernetes
	input.kind == "ServiceAccount"
	role_arn := input.metadata.annotations["eks.amazonaws.com/role-arn"]
	not allowed_irsa_role(role_arn)
	msg := sprintf("%s: IAM role %q is not allowed for IRSA", [resource_id, role_arn])
}

allowed_irsa_role(role_arn) if {
	some prefix in data.allowlist.kubernetes_irsa_role_arn_prefixes
	startswith(role_arn, prefix)
}

# METADATA
# scope: rule
# title: "type: LoadBalancerのServiceを作らない"
# description: "type: LoadBalancer の Service は、Terraform の管理外にAWSのロードバランサーを作る。"
# custom:
#   remediation: type を ClusterIP にする。外部に公開する経路は、Terraform で管理する。
deny contains msg if {
	is_kubernetes
	input.kind == "Service"
	input.spec.type == "LoadBalancer"
	msg := sprintf("%s: Service type LoadBalancer is not allowed", [resource_id])
}
