## 概要
構成: Rails + Nginx(ソケット通信) + Aurora DB

## rails db:migrate の実行方法
タスク定義しかしていないので、実際に実行するにはAWS上で実行する必要がある。

ECRのイメージのbuildを自動化するために利用するAWSの`Code Build`や`GitHub Aciton`で一緒に`rails db:migrate`を実行するのが一般的だと思う。

## 秘匿情報の管理
環境変数で管理している秘匿情報を、AWS Systems Managerのパラメータストアを利用して管理するのが良さそう。

terrafromを使って自動化もできるけど、手作業でパラメータストアに保存しても、あまり煩雑にならないので良いかもしれない。

以下の例では、`/app/master_key`として`RAILS_MASTER_KEY`を保存していた場合の例。

```diff
     "environment": [
         { "name": "RAILS_ENV", "value": "production" },
-        { "name": "RAILS_MASTER_KEY", "value": "${rails_master_key}" },
         { "name": "DATABASE_HOST", "value": "${db_host}" },
         { "name": "DATABASE_USERNAME", "value": "${db_user}" },
         { "name": "DATABASE_PASSWORD", "value": "${db_password}" }
     ],
+    "secrets": [
+      {
+        "name": "RAILS_MASTER_KEY",
+        "valueFrom": "/app/master_key"
+      }
+    ]
```

## 参照
- [Pragmatic Terraform on AWS](https://booth.pm/ja/items/1318735)
- [Terraformで構築するAWS](https://y-ohgi.com/introduction-terraform/handson/ecs/)
