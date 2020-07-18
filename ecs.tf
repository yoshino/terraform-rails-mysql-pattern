data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # アカウントID
  account_id = data.aws_caller_identity.current.account_id

  # プロビジョニングを実行するリージョン
  region = data.aws_region.current.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
	name = "ecs_task_execution_role"
	assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-policy" {
	role = aws_iam_role.ecs_task_execution_role.name
	policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr-read-policy" {
	role = aws_iam_role.ecs_task_execution_role.name
	policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Task Definition
# https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html
data "template_file" "container_definitions" {
  template = file("${path.module}/container_definitions.json")

  vars = {
    account_id = local.account_id
    region     = local.region
    image_name   = "app" # var.image_name
    image_tag = "1.0"

    db_host = aws_rds_cluster.this.endpoint
    db_user = var.db_user
    db_password = var.db_password
    db_name     = var.db_name

    rails_master_key = var.rails_master_key
  }
}

// container_definition.jsonで`awslogs-group`のプロパティにnameの値を設定する
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.image_name}"
  retention_in_days = "7"
}
resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/nginx"
  retention_in_days = "7"
}

resource "aws_ecs_task_definition" "main" {
	family = var.prefix

	# データプレーンの選択
	requires_compatibilities = ["FARGATE"]

	# ECSタスクが使用可能なリソースの上限
	# タスク内のコンテナはこの上限内に使用するリソースを収める必要があり
	# メモリが上限に達した場合OOM Killer にタスクがキルされる
	cpu    = "256"
	memory = "512"

	# ECSタスクのネットワークドライバ
	# Fargateを使用する場合は"awsvpc"決め打ち
	network_mode = "awsvpc"

	# ECRからDocker ImageをPULLするための権限
	execution_role_arn = "${aws_iam_role.ecs_task_execution_role.arn}"

	# 起動するコンテナの定義
	# 【解説1】JSONでコンテナを定義します
	# 【解説2】JSON内の environment で環境変数を設定します。
	# environment ではデータベースのホストを設定しています。
	# 機密情報（次の項目で設定します）として登録するか迷いましたが、
	# 機密情報だとパラメータストアを経由する必要があり、
	# 手動設定が必要になるので、環境変数にしました。
	# プライベートサブネットに入ってるので大丈夫だと考えています。
	# 【解説3】JSON内の secrets で機密情報を設定します。
	# 今回はよく使いそうなものを適当に定義しました。
	# 機密情報 は System Manager のパラメータストアから持ってきます。
  container_definitions = data.template_file.container_definitions.rendered
  volume {
    name      = "socket-data"
  }
  volume {
    name      = "public-data"
  }
}


# ECS Cluster
# https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html
resource "aws_ecs_cluster" "main" {
	name = var.prefix
}

# ELB Target Group
# https://www.terraform.io/docs/providers/aws/r/lb_target_group.html
resource "aws_lb_target_group" "main" {
	name = var.prefix

	# ターゲットグループを作成するVPC
	vpc_id = "${aws_vpc.main.id}"

	# ALBからECSタスクのコンテナへトラフィックを振り分ける設定
	port        = 8080
	protocol    = "HTTP"
	target_type = "ip"

	# コンテナへの死活監視設定
	health_check {
		port = 8080
		path = "/"
	}
}

# ALB Listener Rule
# https://www.terraform.io/docs/providers/aws/r/lb_listener_rule.html
resource "aws_lb_listener_rule" "main" {
	# ルールを追加するリスナー
	listener_arn = aws_lb_listener.main.arn

	# 受け取ったトラフィックをターゲットグループへ受け渡す
	action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.main.id
	}

	# ターゲットグループへ受け渡すトラフィックの条件
	condition {
		field  = "path-pattern"
		values = ["*"]
	}
}

# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "ecs" {
	name        = "${var.prefix}-ecs"
	description = "${var.prefix} ecs"

	# セキュリティグループを配置するVPC
	vpc_id      = aws_vpc.main.id

	# セキュリティグループ内のリソースからインターネットへのアクセス許可設定
	# 今回の場合DockerHubへのPullに使用する。
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "${var.prefix}-ecs"
	}
}

# SecurityGroup Rule
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group_rule" "ecs" {
	security_group_id = aws_security_group.ecs.id

	# インターネットからセキュリティグループ内のリソースへのアクセス許可設定
	type = "ingress"

	# TCPでの80ポートへのアクセスを許可する
	from_port = 80
	to_port   = 8080
	protocol  = "tcp"

	# 同一VPC内からのアクセスのみ許可
	cidr_blocks = ["10.0.0.0/16"]
}

# ECS Service
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html
resource "aws_ecs_service" "main" {
	name = var.prefix

	# 依存関係の記述。
	# "aws_lb_listener_rule.main" リソースの作成が完了するのを待ってから当該リソースの作成を開始する。
	# "depends_on" は "aws_ecs_service" リソース専用のプロパティではなく、Terraformのシンタックスのため他の"resource"でも使用可能
	depends_on = ["aws_lb_listener_rule.main"]

	# 当該ECSサービスを配置するECSクラスターの指定
	cluster = aws_ecs_cluster.main.name

	# データプレーンとしてFargateを使用する
	launch_type = "FARGATE"

	# ECSタスクの起動数を定義
	desired_count = "1"

	# 起動するECSタスクのタスク定義
	task_definition = aws_ecs_task_definition.main.arn

	# ECSタスクへ設定するネットワークの設定
	network_configuration {
		# タスクの起動を許可するサブネット
		subnets         = [aws_subnet.private_1a.id, aws_subnet.private_1c.id, aws_subnet.private_1d.id]
		# タスクに紐付けるセキュリティグループ
		security_groups = [aws_security_group.ecs.id]
	}

	# ECSタスクの起動後に紐付けるELBターゲットグループ
	load_balancer {
			target_group_arn = aws_lb_target_group.main.arn
			container_name   = "nginx"
			container_port   = "8080"
		}
}
