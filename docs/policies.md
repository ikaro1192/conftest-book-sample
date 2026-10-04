# ポリシーの一覧

このファイルは`scripts/policy-docs.sh`で生成する。直接編集しない。

## `dockerfile`: Dockerfileの規約

conftest が解析したDockerfileの命令の配列を検査する。

### ベースイメージのタグを固定する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/dockerfile/dockerfile.rego` |
| 説明 | FROM のイメージに、latest 以外のタグかダイジェストを指定する。 |
| 修正方法 | golang:1.27 のようにタグを書くか、@sha256: に続けてダイジェストを書く。 |
| 参考 | - |

### ベースイメージを許可リストに限る

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/dockerfile/dockerfile.rego` |
| 説明 | FROM のイメージのリポジトリは、data.allowlist.dockerfile_base_image_repositories のいずれかとする。 |
| 修正方法 | 許可リストにあるリポジトリを使う。別のリポジトリが必要な場合は、利用側の許可リストに加える。 |
| 参考 | - |

### 最終ステージでUSERを指定する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/dockerfile/dockerfile.rego` |
| 説明 | 最終ステージに USER 命令が無いと、コンテナは root で動く。 |
| 修正方法 | 最終ステージに USER nonroot や USER 10001 のように、root 以外のユーザーを書く。 |
| 参考 | - |

### 最終ステージでrootをUSERにしない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/dockerfile/dockerfile.rego` |
| 説明 | 最終ステージの最後の USER 命令のユーザーは、root と 0 以外とする。 |
| 修正方法 | 最終ステージの USER に、root 以外のユーザーを書く。 |
| 参考 | - |

### ADDではなくCOPYを使う

| 項目 | 内容 |
| --- | --- |
| ルール | `warn` |
| ファイル | `policy/dockerfile/dockerfile.rego` |
| 説明 | ADD は、URLからの取得とアーカイブの展開も行う。ファイルのコピーには COPY を使う。 |
| 修正方法 | ADD を COPY に書き換える。 |
| 参考 | https://docs.docker.com/build/building/best-practices/#add-or-copy |

## `kubernetes`: Kubernetesマニフェストの規約

Kubernetesマニフェストの一つのドキュメントを検査する。--combine を指定せずに使う。

### 特権コンテナを使わない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | コンテナの securityContext.privileged を true にしない。 |
| 修正方法 | securityContext.privileged を削除するか、false にする。 |
| 参考 | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

### ノードの名前空間を共有しない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | Pod の hostNetwork・hostPID・hostIPC を true にしない。 |
| 修正方法 | これらのフィールドを削除するか、false にする。 |
| 参考 | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

### CPUとメモリのrequestsとlimitsを指定する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | initContainers を含むすべてのコンテナで、resources.requests と resources.limits の cpu と memory を指定する。 |
| 修正方法 | resources に requests と limits の cpu と memory の四つの値を書く。 |
| 参考 | https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |

### コンテナイメージのタグを固定する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | コンテナの image に、latest 以外のタグかダイジェストを指定する。 |
| 修正方法 | v0.1.0 のようにタグを書くか、@sha256: に続けてダイジェストを書く。 |
| 参考 | - |

### コンテナをroot以外のユーザーで実行する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | Pod かコンテナの securityContext.runAsNonRoot を true にする。コンテナの値は、Pod の値より優先される。 |
| 修正方法 | Pod の securityContext に runAsNonRoot: true を書く。イメージの USER が nonroot のような名前の場合は、runAsUser に数値のUIDも書く。 |
| 参考 | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

### ルートファイルシステムを読み取り専用にする

| 項目 | 内容 |
| --- | --- |
| ルール | `deny_read_only_root_filesystem` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | コンテナの securityContext.readOnlyRootFilesystem を true にする。この規約は、data.exceptions.kubernetes で例外にできる。 |
| 修正方法 | readOnlyRootFilesystem: true を書く。書き込みが必要なディレクトリには、emptyDir のボリュームをマウントする。 |
| 参考 | - |

### defaultのServiceAccountを使わない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | Pod の serviceAccountName を指定し、default 以外とする。 |
| 修正方法 | アプリケーション専用の ServiceAccount を作り、serviceAccountName に指定する。 |
| 参考 | - |

### IRSAのIAMロールを許可リストに限る

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | ServiceAccount の eks.amazonaws.com/role-arn は、data.allowlist.kubernetes_irsa_role_arn_prefixes のいずれかで始まる。 |
| 修正方法 | 許可リストの接頭辞で始まるIAMロールを使う。 |
| 参考 | https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html |

### type: LoadBalancerのServiceを作らない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | type: LoadBalancer の Service は、Terraform の管理外にAWSのロードバランサーを作る。 |
| 修正方法 | type を ClusterIP にする。外部に公開する経路は、Terraform で管理する。 |
| 参考 | - |

### Deploymentのreplicasを2以上にする

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes/kubernetes.rego` |
| 説明 | Deployment の replicas を2以上にする。replicas を省略した場合は1として扱う。 |
| 修正方法 | replicas に2以上の値を書く。 |
| 参考 | - |

## `kubernetes_combined`: Kubernetesマニフェストの組み合わせの規約

--combine で一つにまとめた複数のドキュメントを検査する。

### Serviceのselectorに一致するPodテンプレートを置く

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/kubernetes_combined/service_selector.rego` |
| 説明 | Service の spec.selector のすべてのラベルを持つPodテンプレートが、同じ入力にある。 |
| 修正方法 | selector を、接続先のPodテンプレートの labels に合わせる。 |
| 参考 | - |

## `terraform`: Terraformのplan結果の規約

terraform show -json で出力したplan結果を検査する。

### ECRリポジトリのタグを変更不可にする

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/ecr.rego` |
| 説明 | aws_ecr_repository の image_tag_mutability を IMMUTABLE にする。 |
| 修正方法 | image_tag_mutability = "IMMUTABLE" を書く。 |
| 参考 | https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html |

### ECRリポジトリのプッシュ時スキャンを有効にする

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/ecr.rego` |
| 説明 | aws_ecr_repository の image_scanning_configuration.scan_on_push を true にする。 |
| 修正方法 | image_scanning_configuration ブロックに scan_on_push = true を書く。 |
| 参考 | - |

### ECRリポジトリをKMSで暗号化する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/ecr.rego` |
| 説明 | aws_ecr_repository の encryption_configuration.encryption_type を KMS にする。 |
| 修正方法 | encryption_configuration ブロックに encryption_type = "KMS" を書く。 |
| 参考 | - |

### EKSクラスタのAPIエンドポイントを公開しない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/eks.rego` |
| 説明 | aws_eks_cluster の vpc_config.endpoint_public_access を false にする。 |
| 修正方法 | vpc_config に endpoint_public_access = false を書く。 |
| 参考 | https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html |

### EKSクラスタのSecretを暗号化する

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/eks.rego` |
| 説明 | aws_eks_cluster の encryption_config の resources に secrets を含める。 |
| 修正方法 | encryption_config ブロックを書き、resources に secrets、provider に KMS キーを指定する。 |
| 参考 | https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html |

### ノードグループのインスタンスタイプを許可リストに限る

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/eks.rego` |
| 説明 | aws_eks_node_group の instance_types は、data.allowlist.eks_node_instance_types のいずれかとする。 |
| 修正方法 | 許可リストにあるインスタンスタイプを使う。別のタイプが必要な場合は、利用側の許可リストに加える。 |
| 参考 | - |

### IAMポリシーで全アクションを許可しない

| 項目 | 内容 |
| --- | --- |
| ルール | `deny` |
| ファイル | `policy/terraform/eks.rego` |
| 説明 | aws_iam_policy と aws_iam_role_policy の Effect が Allow の文で、Action に "*" を書かない。 |
| 修正方法 | 必要なアクションを列挙する。 |
| 参考 | https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html |

### applyまで内容が決まらないIAMポリシーを警告する

| 項目 | 内容 |
| --- | --- |
| ルール | `warn` |
| ファイル | `policy/terraform/eks.rego` |
| 説明 | policy の値が after_unknown のIAMポリシーは、plan結果では検査できない。 |
| 修正方法 | planの時点で値が決まる入力だけでポリシーの文書を組み立てる。 |
| 参考 | - |

